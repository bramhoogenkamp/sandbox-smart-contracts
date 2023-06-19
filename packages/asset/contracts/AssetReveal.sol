//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "./libraries/TokenIdUtils.sol";
import "./AuthValidator.sol";
import "./ERC2771Handler.sol";
import "./interfaces/IAsset.sol";
import "./interfaces/IAssetReveal.sol";

/// @title AssetReveal
/// @author The Sandbox
/// @notice Contract for burning and revealing assets
contract AssetReveal is
    IAssetReveal,
    Initializable,
    ERC2771Handler,
    EIP712Upgradeable
{
    using TokenIdUtils for uint256;
    IAsset private assetContract;
    AuthValidator private authValidator;

    // mapping of creator to asset id to asset's reveal nonce
    mapping(address => mapping(uint256 => uint16)) revealIds;
    // signature nonces to prevent replay attacks
    mapping(address => uint32) public nonce;

    bytes32 public constant REVEAL_TYPEHASH =
        keccak256(
            "Reveal(address recipient,uint256 prevTokenId,uint32 nonce,uint256[] amounts,string[] metadataHashes)"
        );
    bytes32 public constant BATCH_REVEAL_TYPEHASH =
        keccak256(
            "BatchReveal(address recipient,uint256[] prevTokenIds,uint32 nonce,uint256[][] amounts,string[][] metadataHashes)"
        );
    bytes32 public constant INSTANT_REVEAL_TYPEHASH =
        keccak256(
            "InstantReveal(address recipient,uint256 prevTokenId,uint32 nonce,uint256[] amounts,string[] metadataHashes)"
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
        address _authValidator,
        address _forwarder
    ) public initializer {
        assetContract = IAsset(_assetContract);
        authValidator = AuthValidator(_authValidator);
        __ERC2771Handler_initialize(_forwarder);
        __EIP712_init(_name, _version);
    }

    /// @notice Reveal an asset to view its abilities and enhancements
    /// @dev the reveal mechanism works through burning the asset and minting a new one with updated tokenId
    /// @param tokenId the tokenId of id idasset to reveal
    /// @param amount the amount of tokens to reveal
    function revealBurn(uint256 tokenId, uint256 amount) public {
        _burnAsset(tokenId, amount);
    }

    /// @notice Burn multiple assets to be able to reveal them later
    /// @dev Can be used to burn multiple copies of the same token id, each copy will be revealed separately
    /// @param tokenIds the tokenIds of the assets to burn
    /// @param amounts the amounts of the assets to burn
    function revealBatchBurn(
        uint256[] calldata tokenIds,
        uint256[] calldata amounts
    ) external {
        require(tokenIds.length == amounts.length, "Invalid input");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _burnAsset(tokenIds[i], amounts[i]);
        }
    }

    /// @notice Reveal assets to view their abilities and enhancements
    /// @dev Can be used to reveal multiple copies of the same token id
    /// @param signature Signature created on the TSB backend containing REVEAL_TYPEHASH and associated data, must be signed by authorized signer
    /// @param prevTokenId The tokenId of the unrevealed asset
    /// @param amounts The amount of assets to reveal (must be equal to the length of revealHashes)
    /// @param metadataHashes The array of hashes for asset metadata
    function revealMint(
        bytes memory signature,
        uint256 prevTokenId,
        uint256[] calldata amounts,
        string[] calldata metadataHashes
    ) public {
        require(
            authValidator.verify(
                signature,
                _hashReveal(
                    _msgSender(),
                    prevTokenId,
                    nonce[_msgSender()]++,
                    amounts,
                    metadataHashes
                )
            ),
            "Invalid signature"
        );
        require(amounts.length == metadataHashes.length, "Invalid amount");
        _revealAsset(prevTokenId, metadataHashes, amounts);
    }

    /// @notice Mint multiple assets with revealed abilities and enhancements
    /// @dev Can be used to reveal multiple copies of the same token id
    /// @param signature Signatures created on the TSB backend containing REVEAL_TYPEHASH and associated data, must be signed by authorized signer
    /// @param prevTokenIds The tokenId of the unrevealed asset
    /// @param amounts The amount of assets to reveal (must be equal to the length of revealHashes)
    /// @param metadataHashes The array of hashes for asset metadata
    function revealBatchMint(
        bytes calldata signature,
        uint256[] calldata prevTokenIds,
        uint256[][] calldata amounts,
        string[][] calldata metadataHashes
    ) public {
        require(
            authValidator.verify(
                signature,
                _hashBatchReveal(
                    _msgSender(),
                    prevTokenIds,
                    nonce[_msgSender()]++,
                    amounts,
                    metadataHashes
                )
            ),
            "Invalid signature"
        );
        require(amounts.length == metadataHashes.length, "Invalid amount");
        require(amounts.length == metadataHashes.length, "Invalid input");
        require(prevTokenIds.length == amounts.length, "Invalid input");

        for (uint256 i = 0; i < prevTokenIds.length; i++) {
            _revealAsset(prevTokenIds[i], metadataHashes[i], amounts[i]);
        }
    }

    /// @notice Reveal assets to view their abilities and enhancements and mint them in a single transaction
    /// @dev Should be used where it is not required to keep the metadata secret, e.g. mythical assets where users select their desired abilities and enhancements
    /// @param signature Signature created on the TSB backend containing INSTANT_REVEAL_TYPEHASH and associated data, must be signed by authorized signer
    /// @param prevTokenId The tokenId of the unrevealed asset
    /// @param burnAmount The amount of assets to burn
    /// @param amounts The amount of assets to reveal (sum must be equal to the burnAmount)
    /// @param metadataHashes The array of hashes for asset metadata
    function burnAndReveal(
        bytes memory signature,
        uint256 prevTokenId,
        uint256 burnAmount,
        uint256[] calldata amounts,
        string[] calldata metadataHashes
    ) external {
        require(
            authValidator.verify(
                signature,
                _hashInstantReveal(
                    _msgSender(),
                    prevTokenId,
                    nonce[_msgSender()]++,
                    amounts,
                    metadataHashes
                )
            ),
            "Invalid signature"
        );
        _burnAsset(prevTokenId, burnAmount);
        _revealAsset(prevTokenId, metadataHashes, amounts);
    }

    /// @notice Generate new tokenIds for revealed assets and mint them
    /// @param prevTokenId The tokenId of the unrevealed asset
    /// @param metadataHashes The array of hashes for asset metadata
    /// @param amounts The array of amounts to mint
    function _revealAsset(
        uint256 prevTokenId,
        string[] calldata metadataHashes,
        uint256[] calldata amounts
    ) internal {
        uint256[] memory newTokenIds = getRevealedTokenIds(
            amounts,
            metadataHashes,
            prevTokenId
        );

        if (newTokenIds.length == 1) {
            assetContract.mint(
                _msgSender(),
                newTokenIds[0],
                amounts[0],
                metadataHashes[0]
            );
        } else {
            assetContract.mintBatch(
                _msgSender(),
                newTokenIds,
                amounts,
                metadataHashes
            );
        }
        emit AssetRevealMint(_msgSender(), prevTokenId, amounts, newTokenIds);
    }

    /// @notice Burns an asset to be able to reveal it later
    /// @param tokenId the tokenId of the asset to burn
    /// @param amount the amount of the asset to burn
    function _burnAsset(uint256 tokenId, uint256 amount) internal {
        require(amount > 0, "Amount should be greater than 0");
        IAsset.AssetData memory data = tokenId.getData();
        require(!data.revealed, "Asset is already revealed");
        assetContract.burnFrom(_msgSender(), tokenId, amount);
        emit AssetRevealBurn(_msgSender(), tokenId, data.tier, amount);
    }

    /// @notice Creates a hash of the reveal data
    /// @param recipient The address of the recipient
    /// @param prevTokenId The unrevealed token id
    /// @param signatureNonce The nonce of the signature
    /// @param amounts The amount of tokens to mint
    /// @param metadataHashes The array of hashes for new asset metadata
    function _hashInstantReveal(
        address recipient,
        uint256 prevTokenId,
        uint32 signatureNonce,
        uint256[] calldata amounts,
        string[] calldata metadataHashes
    ) internal view returns (bytes32 digest) {
        digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    INSTANT_REVEAL_TYPEHASH,
                    recipient,
                    prevTokenId,
                    signatureNonce,
                    keccak256(abi.encodePacked(amounts)),
                    _encodeHashes(metadataHashes)
                )
            )
        );
    }

    /// @notice Creates a hash of the reveal data
    /// @param prevTokenId The previous token id
    /// @param amounts The amount of tokens to mint
    /// @return digest The hash of the reveal data
    function _hashReveal(
        address recipient,
        uint256 prevTokenId,
        uint32 signatureNonce,
        uint256[] calldata amounts,
        string[] calldata metadataHashes
    ) internal view returns (bytes32 digest) {
        digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    REVEAL_TYPEHASH,
                    recipient,
                    prevTokenId,
                    signatureNonce,
                    keccak256(abi.encodePacked(amounts)),
                    _encodeHashes(metadataHashes)
                )
            )
        );
    }

    /// @notice Creates a hash of the reveal data
    /// @param prevTokenIds The previous token id
    /// @param amounts The amount of tokens to mint
    /// @return digest The hash of the reveal data
    function _hashBatchReveal(
        address recipient,
        uint256[] calldata prevTokenIds,
        uint32 signatureNonce,
        uint256[][] calldata amounts,
        string[][] calldata metadataHashes
    ) internal view returns (bytes32 digest) {
        digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    BATCH_REVEAL_TYPEHASH,
                    recipient,
                    keccak256(abi.encodePacked(prevTokenIds)),
                    signatureNonce,
                    _encodeBatchAmounts(amounts),
                    _encodeBatchHashes(metadataHashes)
                )
            )
        );
    }

    /// @notice Encodes the hashes of the metadata for signature verification
    /// @param metadataHashes The hashes of the metadata
    /// @return encodedHashes The encoded hashes of the metadata
    function _encodeHashes(
        string[] memory metadataHashes
    ) internal pure returns (bytes32) {
        bytes32[] memory encodedHashes = new bytes32[](metadataHashes.length);
        for (uint256 i = 0; i < metadataHashes.length; i++) {
            encodedHashes[i] = keccak256((abi.encodePacked(metadataHashes[i])));
        }
        return keccak256(abi.encodePacked(encodedHashes));
    }

    /// @notice Encodes the hashes of the metadata for signature verification
    /// @param metadataHashes The hashes of the metadata
    /// @return encodedHashes The encoded hashes of the metadata
    function _encodeBatchHashes(
        string[][] memory metadataHashes
    ) internal pure returns (bytes32) {
        bytes32[] memory encodedHashes = new bytes32[](metadataHashes.length);
        for (uint256 i = 0; i < metadataHashes.length; i++) {
            encodedHashes[i] = _encodeHashes(metadataHashes[i]);
        }
        return keccak256(abi.encodePacked(encodedHashes));
    }

    /// @notice Encodes the amounts of the tokens for signature verification
    /// @param amounts The amounts of the tokens
    /// @return encodedAmounts The encoded amounts of the tokens
    function _encodeBatchAmounts(
        uint256[][] memory amounts
    ) internal pure returns (bytes32) {
        bytes32[] memory encodedAmounts = new bytes32[](amounts.length);
        for (uint256 i = 0; i < amounts.length; i++) {
            encodedAmounts[i] = keccak256(abi.encodePacked(amounts[i]));
        }
        return keccak256(abi.encodePacked(encodedAmounts));
    }

    /// @notice Checks if each metadatahash has been used before to either get the tokenId that was already created for it or generate a new one if it hasn't
    /// @dev This function also validates that we're not trying to reveal a tokenId that has already been revealed
    /// @param amounts The amounts of tokens to mint
    /// @param metadataHashes The hashes of the metadata
    /// @param prevTokenId The previous token id from which the assets are revealed
    /// @return tokenIdArray The array of tokenIds to mint
    function getRevealedTokenIds(
        uint256[] calldata amounts,
        string[] calldata metadataHashes,
        uint256 prevTokenId
    ) internal returns (uint256[] memory) {
        IAsset.AssetData memory data = prevTokenId.getData();
        require(!data.revealed, "Asset: already revealed");

        uint256[] memory tokenIdArray = new uint256[](amounts.length);
        for (uint256 i = 0; i < amounts.length; i++) {
            uint256 tokenId = assetContract.getTokenIdByMetadataHash(
                metadataHashes[i]
            );
            if (tokenId != 0) {
                tokenId = assetContract.getTokenIdByMetadataHash(
                    metadataHashes[i]
                );
            } else {
                uint16 revealNonce = ++revealIds[data.creator][prevTokenId];
                tokenId = TokenIdUtils.generateTokenId(
                    data.creator,
                    data.tier,
                    data.creatorNonce,
                    revealNonce
                );
            }
            tokenIdArray[i] = tokenId;
        }

        return tokenIdArray;
    }

    /// @notice Get the asset contract address
    /// @return The asset contract address
    function getAssetContract() external view returns (address) {
        return address(assetContract);
    }

    /// @notice Get the auth validator address
    /// @return The auth validator address
    function getAuthValidator() external view returns (address) {
        return address(authValidator);
    }
}
