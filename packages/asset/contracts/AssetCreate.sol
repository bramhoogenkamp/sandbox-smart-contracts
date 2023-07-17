//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {
    AccessControlUpgradeable,
    ContextUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {TokenIdUtils} from "./libraries/TokenIdUtils.sol";
import {AuthValidator} from "./AuthValidator.sol";
import {ERC2771Handler} from "./ERC2771Handler.sol";
import {IAsset} from "./interfaces/IAsset.sol";
import {ICatalyst} from "./interfaces/ICatalyst.sol";
import {IAssetCreate} from "./interfaces/IAssetCreate.sol";

/// @title AssetCreate
/// @author The Sandbox
/// @notice User-facing contract for creating new assets
contract AssetCreate is IAssetCreate, Initializable, ERC2771Handler, EIP712Upgradeable, AccessControlUpgradeable {
    using TokenIdUtils for uint256;

    IAsset private assetContract;
    ICatalyst private catalystContract;
    AuthValidator private authValidator;

    // mapping of creator address to creator nonce, a nonce is incremented every time a creator mints a new token
    mapping(address => uint16) public creatorNonces;
    mapping(address => uint16) public signatureNonces;

    bytes32 public constant SPECIAL_MINTER_ROLE = keccak256("SPECIAL_MINTER_ROLE");
    bytes32 public constant BRIDGE_MINTER_ROLE = keccak256("BRIDGE_MINTER_ROLE");
    bytes32 public constant MINT_TYPEHASH =
        keccak256("Mint(address creator,uint16 nonce,uint8 tier,uint256 amount,bool revealed,string metadataHash)");
    bytes32 public constant MINT_BATCH_TYPEHASH =
        keccak256(
            "MintBatch(address creator,uint16 nonce,uint8[] tiers,uint256[] amounts,bool[] revealed,string[] metadataHashes)"
        );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the contract
    /// @param _assetContract The address of the asset contract
    /// @param _authValidator The address of the AuthValidator contract
    /// @param _forwarder The address of the forwarder contract
    function initialize(
        string memory _name,
        string memory _version,
        address _assetContract,
        address _catalystContract,
        address _authValidator,
        address _forwarder,
        address _defaultAdmin
    ) public initializer {
        assetContract = IAsset(_assetContract);
        catalystContract = ICatalyst(_catalystContract);
        authValidator = AuthValidator(_authValidator);
        __ERC2771Handler_initialize(_forwarder);
        __EIP712_init(_name, _version);
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
    }

    /// @notice Create a new asset
    /// @param signature A signature generated by TSB
    /// @param tier The tier of the asset to mint
    /// @param amount The amount of the asset to mint
    /// @param metadataHash The metadata hash of the asset to mint
    function createAsset(
        bytes memory signature,
        uint8 tier,
        uint256 amount,
        bool revealed,
        string calldata metadataHash,
        address creator
    ) external {
        require(
            authValidator.verify(
                signature,
                _hashMint(creator, signatureNonces[_msgSender()]++, tier, amount, revealed, metadataHash)
            ),
            "Invalid signature"
        );

        uint256 tokenId =
            TokenIdUtils.generateTokenId(creator, tier, ++creatorNonces[creator], revealed ? 1 : 0, false);

        // burn catalyst of a given tier
        catalystContract.burnFrom(creator, tier, amount);
        assetContract.mint(creator, tokenId, amount, metadataHash);
        emit AssetMinted(creator, tokenId, tier, amount, metadataHash, revealed);
    }

    /// @notice Create multiple assets at once
    /// @param signature A signature generated by TSB
    /// @param tiers The tiers of the assets to mint
    /// @param amounts The amounts of the assets to mint
    /// @param metadataHashes The metadata hashes of the assets to mint
    function createMultipleAssets(
        bytes memory signature,
        uint8[] calldata tiers,
        uint256[] calldata amounts,
        bool[] calldata revealed,
        string[] calldata metadataHashes,
        address creator
    ) external {
        require(
            authValidator.verify(
                signature,
                _hashBatchMint(creator, signatureNonces[_msgSender()]++, tiers, amounts, revealed, metadataHashes)
            ),
            "Invalid signature"
        );

        require(tiers.length == amounts.length, "Arrays must be same length");
        require(amounts.length == metadataHashes.length, "Arrays must be same length");
        require(metadataHashes.length == revealed.length, "Arrays must be same length");

        uint256[] memory tokenIds = new uint256[](tiers.length);
        uint256[] memory tiersToBurn = new uint256[](tiers.length);
        for (uint256 i = 0; i < tiers.length; i++) {
            tiersToBurn[i] = tiers[i];
            tokenIds[i] = TokenIdUtils.generateTokenId(
                creator,
                tiers[i],
                ++creatorNonces[creator],
                revealed[i] ? 1 : 0,
                false
            );
        }

        catalystContract.burnBatchFrom(creator, tiersToBurn, amounts);

        assetContract.mintBatch(creator, tokenIds, amounts, metadataHashes);
        emit AssetBatchMinted(creator, tokenIds, tiers, amounts, metadataHashes, revealed);
    }

    /// @notice Create special assets, like TSB exclusive tokens
    /// @dev Only callable by the special minter
    /// @param signature A signature generated by TSB
    /// @param tier The tier of the asset to mint
    /// @param amount The amount of the asset to mint
    /// @param metadataHash The metadata hash of the asset to mint
    function createSpecialAsset(
        bytes memory signature,
        uint8 tier,
        uint256 amount,
        bool revealed,
        string calldata metadataHash,
        address creator
    ) external onlyRole(SPECIAL_MINTER_ROLE) {
        require(
            authValidator.verify(
                signature,
                _hashMint(creator, signatureNonces[_msgSender()]++, tier, amount, revealed, metadataHash)
            ),
            "Invalid signature"
        );

        uint256 tokenId =
            TokenIdUtils.generateTokenId(creator, tier, ++creatorNonces[creator], revealed ? 1 : 0, false);

        assetContract.mint(creator, tokenId, amount, metadataHash);
        emit SpecialAssetMinted(creator, tokenId, amount, metadataHash);
    }

    /// @notice Get the next available creator nonce
    /// @dev Called from the bridge contract
    /// @param creator The address of the creator
    /// @return nonce The next available creator nonce
    function bridgeIncrementCreatorNonce(address creator) external onlyRole(BRIDGE_MINTER_ROLE) returns (uint16) {
        return ++creatorNonces[creator];
    }

    /// @notice Get the asset contract address
    /// @return The asset contract address
    function getAssetContract() external view returns (address) {
        return address(assetContract);
    }

    /// @notice Get the catalyst contract address
    /// @return The catalyst contract address
    function getCatalystContract() external view returns (address) {
        return address(catalystContract);
    }

    /// @notice Get the auth validator address
    /// @return The auth validator address
    function getAuthValidator() external view returns (address) {
        return address(authValidator);
    }

    /// @notice Creates a hash of the mint data
    /// @param creator The address of the creator
    /// @param tier The tier of the asset
    /// @param amount The amount of copies to mint
    /// @param metadataHash The metadata hash of the asset
    /// @return digest The hash of the mint data
    function _hashMint(
        address creator,
        uint16 nonce,
        uint8 tier,
        uint256 amount,
        bool revealed,
        string calldata metadataHash
    ) internal view returns (bytes32 digest) {
        digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    MINT_TYPEHASH,
                    creator,
                    nonce,
                    tier,
                    amount,
                    revealed,
                    keccak256((abi.encodePacked(metadataHash)))
                )
            )
        );
    }

    /// @notice Creates a hash of the mint batch data
    /// @param creator The address of the creator
    /// @param tiers The tiers of the assets
    /// @param amounts The amounts of copies to mint
    /// @param metadataHashes The metadata hashes of the assets
    /// @return digest The hash of the mint batch data
    function _hashBatchMint(
        address creator,
        uint16 nonce,
        uint8[] calldata tiers,
        uint256[] calldata amounts,
        bool[] calldata revealed,
        string[] calldata metadataHashes
    ) internal view returns (bytes32 digest) {
        digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    MINT_BATCH_TYPEHASH,
                    creator,
                    nonce,
                    keccak256(abi.encodePacked(tiers)),
                    keccak256(abi.encodePacked(amounts)),
                    keccak256(abi.encodePacked(revealed)),
                    _encodeHashes(metadataHashes)
                )
            )
        );
    }

    /// @notice Encodes the hashes of the metadata for signature verification
    /// @param metadataHashes The hashes of the metadata
    /// @return encodedHashes The encoded hashes of the metadata
    function _encodeHashes(string[] memory metadataHashes) internal pure returns (bytes32) {
        bytes32[] memory encodedHashes = new bytes32[](metadataHashes.length);
        for (uint256 i = 0; i < metadataHashes.length; i++) {
            encodedHashes[i] = keccak256((abi.encodePacked(metadataHashes[i])));
        }

        return keccak256(abi.encodePacked(encodedHashes));
    }

    function _msgSender() internal view virtual override(ContextUpgradeable, ERC2771Handler) returns (address sender) {
        return ERC2771Handler._msgSender();
    }

    function _msgData() internal view virtual override(ContextUpgradeable, ERC2771Handler) returns (bytes calldata) {
        return ERC2771Handler._msgData();
    }
}
