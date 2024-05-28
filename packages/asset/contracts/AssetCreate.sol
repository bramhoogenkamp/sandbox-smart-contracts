//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {
    AccessControlUpgradeable,
    ContextUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {TokenIdUtils} from "./libraries/TokenIdUtils.sol";
import {AuthSuperValidator} from "./AuthSuperValidator.sol";
import {
    ERC2771HandlerUpgradeable
} from "@sandbox-smart-contracts/dependency-metatx/contracts/ERC2771HandlerUpgradeable.sol";
import {IAsset} from "./interfaces/IAsset.sol";
import {ICatalyst} from "./interfaces/ICatalyst.sol";
import {IAssetCreate} from "./interfaces/IAssetCreate.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IExchange, ExchangeMatch} from "./interfaces/IExchange.sol";

/// @title AssetCreate
/// @author The Sandbox
/// @custom:security-contact contact-blockchain@sandbox.game
/// @notice User-facing contract for creating new assets
contract AssetCreate is
    IAssetCreate,
    Initializable,
    ERC2771HandlerUpgradeable,
    EIP712Upgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable
{
    using TokenIdUtils for uint256;
    using Address for address;

    IAsset private assetContract;
    ICatalyst private catalystContract;
    AuthSuperValidator private authValidator;

    /// @notice mapping of creator address to creator nonce, a nonce is incremented every time a creator mints a new token
    mapping(address => uint16) public creatorNonces;
    /// @notice mapping of minter address to signature nonce, a nonce is incremented every time asset minter consumes a signature generated by TSB
    mapping(address => uint16) public signatureNonces;

    /// @notice A fee denoted in BPS that is charged when using the lazy minting feature, deducted from the creators payout
    uint256 public lazyMintFeeInBps;
    /// @notice The address that receives the lazy mint fee
    address public lazyMintFeeReceiver;
    /// @notice mapping of tokenId => maxSupply specified by the creator
    mapping(uint256 => uint256) public availableToMint;

    /// @notice The marketplace exchange contract to purchase catalyst
    IExchange private exchangeContract;

    /// @notice Role allowing to mint special assets
    bytes32 public constant SPECIAL_MINTER_ROLE = keccak256("SPECIAL_MINTER_ROLE");
    /// @notice Role allowing to pause the contract
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    /// @notice Mint signature typehash
    bytes32 public constant MINT_TYPEHASH =
        keccak256("Mint(address creator,uint16 nonce,uint8 tier,uint256 amount,bool revealed,string metadataHash)");
    /// @notice Mint batch signature typehash
    bytes32 public constant MINT_BATCH_TYPEHASH =
        keccak256(
            "MintBatch(address creator,uint16 nonce,uint8[] tiers,uint256[] amounts,bool[] revealed,string[] metadataHashes)"
        );
    /// @notice Lazy mint signature typehash
    bytes32 public constant LAZY_MINT_TYPEHASH =
        keccak256(
            "LazyMint(address caller,address creator,uint16 nonce,uint8 tier,uint256 amount,uint256 unitPrice,address paymentToken,string metadataHash,uint256 maxSupply,uint256 expirationTime)"
        );
    /// @notice Lazy mint batch signature typehash
    bytes32 public constant LAZY_MINT_BATCH_TYPEHASH =
        keccak256(
            "LazyMintBatch(address caller,address[] creators,uint16 nonce,uint8[] tiers,uint256[] amounts,uint256[] unitPrices,address[] paymentTokens,string[] metadataHashes,uint256[] maxSupplies,uint256 expirationTime)"
        );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the contract
    /// @param _name The name of the contract (for EIP712)
    /// @param _version The version of the contract (for EIP712)
    /// @param _assetContract The address of the asset contract
    /// @param _catalystContract The address of the catalyst contract
    /// @param _authValidator The address of the AuthSuperValidator contract
    /// @param _forwarder The address of the forwarder contract
    /// @param _defaultAdmin The address of the default admin
    function initialize(
        string memory _name,
        string memory _version,
        address _assetContract,
        address _catalystContract,
        address _authValidator,
        address _forwarder,
        address _defaultAdmin
    ) external initializer {
        assetContract = IAsset(_assetContract);
        catalystContract = ICatalyst(_catalystContract);
        authValidator = AuthSuperValidator(_authValidator);
        __ERC2771Handler_init(_forwarder);
        __EIP712_init(_name, _version);
        __AccessControl_init();
        __Pausable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
    }

    /// @notice Create a new asset
    /// @param signature A signature generated by TSB
    /// @param tier The tier of the asset to mint
    /// @param amount The amount of the asset to mint
    /// @param revealed Whether the asset is revealed or not
    /// @param metadataHash The metadata hash of the asset to mint
    /// @param creator The address of the creator
    function createAsset(
        bytes memory signature,
        uint8 tier,
        uint256 amount,
        bool revealed,
        string calldata metadataHash,
        address creator
    ) external whenNotPaused {
        require(
            authValidator.verify(
                signature,
                _hashMint(creator, signatureNonces[_msgSender()]++, tier, amount, revealed, metadataHash)
            ),
            "AssetCreate: Invalid signature"
        );

        uint256 tokenId =
            TokenIdUtils.generateTokenId(creator, tier, ++creatorNonces[creator], revealed ? 1 : 0, false);

        // burn catalyst of a given tier, the tier is representing catalyst token id
        catalystContract.burnFrom(creator, tier, amount);
        assetContract.mint(creator, tokenId, amount, metadataHash);
        emit AssetMinted(creator, tokenId, tier, amount, metadataHash, revealed);
    }

    /// @notice Create multiple assets at once
    /// @param signature A signature generated by TSB
    /// @param tiers The tiers of the assets to mint
    /// @param amounts The amounts of the assets to mint
    /// @param revealed Whether the assets are revealed or not
    /// @param metadataHashes The metadata hashes of the assets to mint
    /// @param creator The address of the creator
    function createMultipleAssets(
        bytes memory signature,
        uint8[] calldata tiers,
        uint256[] calldata amounts,
        bool[] calldata revealed,
        string[] calldata metadataHashes,
        address creator
    ) external whenNotPaused {
        require(
            authValidator.verify(
                signature,
                _hashBatchMint(creator, signatureNonces[_msgSender()]++, tiers, amounts, revealed, metadataHashes)
            ),
            "AssetCreate: Invalid signature"
        );

        require(tiers.length == amounts.length, "AssetCreate: 1-Array lengths");
        require(amounts.length == metadataHashes.length, "AssetCreate: 2-Array lengths");
        require(metadataHashes.length == revealed.length, "AssetCreate: 3-Array lengths");

        uint256[] memory tokenIds = new uint256[](tiers.length);
        uint256[] memory tiersToBurn = new uint256[](tiers.length);
        for (uint256 i; i < tiers.length; ) {
            tiersToBurn[i] = tiers[i];
            tokenIds[i] = TokenIdUtils.generateTokenId(
                creator,
                tiers[i],
                ++creatorNonces[creator],
                revealed[i] ? 1 : 0,
                false
            );
            unchecked {++i;}
        }

        catalystContract.burnBatchFrom(creator, tiersToBurn, amounts);

        assetContract.mintBatch(creator, tokenIds, amounts, metadataHashes);
        emit AssetBatchMinted(creator, tokenIds, tiers, amounts, metadataHashes, revealed);
    }

    /// @notice Create special assets
    /// @dev Only callable by the special minter
    /// @param signature A signature generated by TSB
    /// @param amount The amount of the asset to mint
    /// @param metadataHash The metadata hash of the asset to mint,
    /// @param creator The address of the creator
    function createSpecialAsset(
        bytes memory signature,
        uint256 amount,
        string calldata metadataHash,
        address creator
    ) external onlyRole(SPECIAL_MINTER_ROLE) whenNotPaused {
        require(
            authValidator.verify(
                signature,
                _hashMint(creator, signatureNonces[_msgSender()]++, 0, amount, true, metadataHash)
            ),
            "AssetCreate: Invalid signature"
        );

        uint256 tokenId = TokenIdUtils.generateTokenId(creator, 0, ++creatorNonces[creator], 1, false);

        assetContract.mint(creator, tokenId, amount, metadataHash);
        emit SpecialAssetMinted(creator, tokenId, 0, amount, metadataHash, true);
    }

    /// @notice Create multiple special assets
    /// @dev Only callable by the special minter
    /// @param signature A signature generated by TSB
    /// @param amounts The amounts of the assets to mint
    /// @param metadataHashes The metadata hashes of the assets to mint
    /// @param creator The address of the creator
    function createMultipleSpecialAssets(
        bytes memory signature,
        uint256[] calldata amounts,
        string[] calldata metadataHashes,
        address creator
    ) external onlyRole(SPECIAL_MINTER_ROLE) whenNotPaused {
        require(amounts.length == metadataHashes.length, "AssetCreate: Array lengths");

        bool[] memory revealed = new bool[](amounts.length);
        uint8[] memory tier = new uint8[](amounts.length);
        for (uint256 i; i < amounts.length; ) {
            revealed[i] = true;
            tier[i] = 0;
            unchecked {++i;}
        }

        require(
            authValidator.verify(
                signature,
                _hashBatchMint(creator, signatureNonces[_msgSender()]++, tier, amounts, revealed, metadataHashes)
            ),
            "AssetCreate: Invalid signature"
        );

        uint256[] memory tokenIds = new uint256[](amounts.length);
        for (uint256 i; i < amounts.length; ) {
            tokenIds[i] = TokenIdUtils.generateTokenId(creator, 0, ++creatorNonces[creator], 1, false);
            unchecked {++i;}
        }

        assetContract.mintBatch(creator, tokenIds, amounts, metadataHashes);
        emit SpecialAssetBatchMinted(creator, tokenIds, tier, amounts, metadataHashes, revealed);
    }

    /// @notice Lazily creates a new asset with a signature
    /// @dev Allows users to lazy mint assets
    /// @param from The address of the sender
    /// @param signature The signature of the lazy mint generated by TSB
    /// @param mintData The data for the lazy mint
    /// @param matchedOrders The orders to match for catalyst purchase
    function lazyCreateAsset(
        address from,
        bytes memory signature,
        LazyMintData calldata mintData,
        ExchangeMatch[] calldata matchedOrders
    ) external whenNotPaused {
        require(
            authValidator.verify(
                signature,
                _hashLazyMint(
                    mintData.caller,
                    mintData.creator,
                    signatureNonces[mintData.caller]++,
                    mintData.tier,
                    mintData.amount,
                    mintData.unitPrice,
                    mintData.paymentToken,
                    mintData.metadataHash,
                    mintData.maxSupply,
                    mintData.expirationTime
                ),
                mintData.expirationTime
            ),
            "AssetCreate: Invalid signature"
        );

        require(from == mintData.caller, "AssetCreate: Invalid caller");
        // check if asset has already been minted before
        uint256 tokenId = assetContract.getTokenIdByMetadataHash(mintData.metadataHash);
        if (tokenId == 0) {
            tokenId = TokenIdUtils.generateTokenId(
                mintData.creator,
                mintData.tier,
                ++creatorNonces[mintData.creator],
                mintData.tier == 1 ? 1 : 0,
                false
            );
            require(mintData.amount <= mintData.maxSupply, "AssetCreate: Max supply exceeded");
            unchecked {availableToMint[tokenId] = mintData.maxSupply - mintData.amount;}
        } else {
            require(availableToMint[tokenId] >= mintData.amount, "AssetCreate: Max supply reached");
            unchecked {availableToMint[tokenId] -= mintData.amount;}
        }

        if (matchedOrders.length > 0) {
            exchangeContract.matchOrdersFrom(mintData.caller, matchedOrders);
        }
        // burn catalyst of a given tier, the tier is representing catalyst token id
        catalystContract.burnFrom(mintData.caller, mintData.tier, mintData.amount);
        // send the payment to the creator after deducting the lazy mint fee
        distributePayment(
            mintData.caller,
            mintData.unitPrice,
            mintData.amount,
            mintData.paymentToken,
            mintData.creator
        );
        // mint the asset

        assetContract.mint(mintData.caller, tokenId, mintData.amount, mintData.metadataHash);
        emit AssetLazyMinted(
            mintData.caller,
            mintData.creator,
            tokenId,
            mintData.tier,
            mintData.amount,
            mintData.metadataHash
        );
    }

    /// @notice Lazily creates multiple assets with a signature
    /// @dev Allows users to lazy mint assets coming from multiple creators
    /// @param from The address of the sender
    /// @param signature The signature of the lazy mint generated by TSB
    /// @param mintData The data for the lazy mint
    /// @param matchedOrdersArray The orders to match for catalyst purchase
    function lazyCreateMultipleAssets(
        address from,
        bytes memory signature,
        LazyMintBatchData calldata mintData,
        ExchangeMatch[][] calldata matchedOrdersArray
    ) external whenNotPaused {
        require(
            authValidator.verify(
                signature,
                _hashLazyBatchMint(
                    mintData.caller,
                    mintData.creators,
                    signatureNonces[mintData.caller]++,
                    mintData.tiers,
                    mintData.amounts,
                    mintData.unitPrices,
                    mintData.paymentTokens,
                    mintData.metadataHashes,
                    mintData.maxSupplies,
                    mintData.expirationTime
                ),
                mintData.expirationTime
            ),
            "AssetCreate: Invalid signature"
        );

        require(from == mintData.caller, "AssetCreate: Invalid caller");
        uint256 expectedLength = mintData.tiers.length;
        require(mintData.creators.length == expectedLength, "AssetCreate: 1-Array lengths");
        require(mintData.amounts.length == expectedLength, "AssetCreate: 2-Array lengths");
        require(mintData.unitPrices.length == expectedLength, "AssetCreate: 3-Array lengths");
        require(mintData.paymentTokens.length == expectedLength, "AssetCreate: 4-Array lengths");
        require(mintData.metadataHashes.length == expectedLength, "AssetCreate: 5-Array lengths");
        require(mintData.maxSupplies.length == expectedLength, "AssetCreate: 6-Array lengths");

        uint256[] memory tokenIds = new uint256[](mintData.tiers.length);
        uint256[] memory tiersToBurn = new uint256[](mintData.tiers.length);
        for (uint256 i; i < mintData.tiers.length; ) {
            uint16 revealed = mintData.tiers[i] == 1 ? 1 : 0;
            tiersToBurn[i] = mintData.tiers[i];
            tokenIds[i] = assetContract.getTokenIdByMetadataHash(mintData.metadataHashes[i]);
            if (tokenIds[i] == 0) {
                tokenIds[i] = TokenIdUtils.generateTokenId(
                    mintData.creators[i],
                    mintData.tiers[i],
                    ++creatorNonces[mintData.creators[i]],
                    revealed,
                    false
                );
                require(mintData.amounts[i] <= mintData.maxSupplies[i], "AssetCreate: Max supply exceeded");
                unchecked {availableToMint[tokenIds[i]] = mintData.maxSupplies[i] - mintData.amounts[i];}
            } else {
                require(availableToMint[tokenIds[i]] >= mintData.amounts[i], "AssetCreate: Max supply reached");
                unchecked {availableToMint[tokenIds[i]] -= mintData.amounts[i];}
            }
            if (matchedOrdersArray.length > i && matchedOrdersArray[i].length > 0) {
                exchangeContract.matchOrdersFrom(mintData.caller, matchedOrdersArray[i]);
            }
            distributePayment(
                mintData.caller,
                mintData.unitPrices[i],
                mintData.amounts[i],
                mintData.paymentTokens[i],
                mintData.creators[i]
            );
            unchecked {++i;}
        }

        catalystContract.burnBatchFrom(mintData.caller, tiersToBurn, mintData.amounts);
        assetContract.mintBatch(mintData.caller, tokenIds, mintData.amounts, mintData.metadataHashes);
        emit AssetBatchLazyMinted(
            mintData.caller,
            mintData.creators,
            tokenIds,
            mintData.tiers,
            mintData.amounts,
            mintData.metadataHashes
        );
    }

    /// @notice Pause the contracts mint and burn functions
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @notice Unpause the contracts mint and burn functions
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /// @notice Set the lazy mint fee
    /// @param _lazyMintFeeInBps The fee to set
    function setLazyMintFee(uint256 _lazyMintFeeInBps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_lazyMintFeeInBps <= 10000, "AssetCreate: Invalid fee");
        lazyMintFeeInBps = _lazyMintFeeInBps;
        emit LazyMintFeeSet(_lazyMintFeeInBps);
    }

    /// @notice Set the lazy mint fee receiver
    /// @param _lazyMintFeeReceiver The receiver to set
    function setLazyMintFeeReceiver(address _lazyMintFeeReceiver) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_lazyMintFeeReceiver != address(0), "AssetCreate: Invalid receiver");
        lazyMintFeeReceiver = _lazyMintFeeReceiver;
        emit LazyMintFeeReceiverSet(_lazyMintFeeReceiver);
    }

    /// @notice Set the exchange contract
    /// @param _exchangeContract The exchange contract to set
    function setExchangeContract(address _exchangeContract) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_exchangeContract.isContract(), "AssetCreate: Invalid contract");
        exchangeContract = IExchange(_exchangeContract);
        emit ExchangeContractSet(_exchangeContract);
    }

    /// @notice Set a new trusted forwarder address, limited to DEFAULT_ADMIN_ROLE only
    /// @dev Change the address of the trusted forwarder for meta-TX
    /// @param trustedForwarder The new trustedForwarder
    function setTrustedForwarder(address trustedForwarder) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(trustedForwarder.isContract(), "AssetCreate: Bad forwarder addr");
        _setTrustedForwarder(trustedForwarder);
    }

    /// @notice Set the auth validator contract address
    /// @param _authValidator The auth validator contract address to set
    function setAuthValidator(address _authValidator) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_authValidator.isContract(), "AssetCreate: Invalid contract");
        authValidator = AuthSuperValidator(_authValidator);
        emit AuthValidatorSet(_authValidator);
    }

    /// @notice Get the asset contract address
    /// @return assetContractAddress The asset contract address
    function getAssetContract() external view returns (address assetContractAddress) {
        return address(assetContract);
    }

    /// @notice Get the catalyst contract address
    /// @return catalystContractAddress The catalyst contract address
    function getCatalystContract() external view returns (address catalystContractAddress) {
        return address(catalystContract);
    }

    /// @notice Get the auth validator address
    /// @return authValidatorAddress The auth validator address
    function getAuthValidator() external view returns (address authValidatorAddress) {
        return address(authValidator);
    }

    /// @notice Get the exchange contract address
    /// @return exchangeContractAddress The exchange contract address
    function getExchangeContract() external view returns (address exchangeContractAddress) {
        return address(exchangeContract);
    }

    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771HandlerUpgradeable)
        returns (address sender)
    {
        return ERC2771HandlerUpgradeable._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771HandlerUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771HandlerUpgradeable._msgData();
    }

    /// @notice Splits the lazy mint payment between the creator and TSB if there is a fee
    /// @param from The address of the sender
    /// @param unitPrice The price of the asset
    /// @param amount The amount of copies to mint
    /// @param paymentToken The payment token
    /// @param creator The address of the creator
    function distributePayment(
        address from,
        uint256 unitPrice,
        uint256 amount,
        address paymentToken,
        address creator
    ) private {
        uint256 fee;
        if (lazyMintFeeInBps > 0) {
            fee = (unitPrice * amount * lazyMintFeeInBps) / 10000;
            SafeERC20.safeTransferFrom(IERC20(paymentToken), from, lazyMintFeeReceiver, fee);
        }
        uint256 creatorPayment = unitPrice * amount - fee;
        SafeERC20.safeTransferFrom(IERC20(paymentToken), from, creator, creatorPayment);
    }

    /// @notice Creates a hash of the mint data
    /// @param creator The address of the creator
    /// @param nonce The nonce of the creator
    /// @param tier The tier of the asset
    /// @param amount The amount of copies to mint
    /// @param revealed Whether the asset is revealed or not
    /// @param metadataHash The metadata hash of the asset
    /// @return digest The hash of the mint data
    function _hashMint(
        address creator,
        uint16 nonce,
        uint8 tier,
        uint256 amount,
        bool revealed,
        string memory metadataHash
    ) private view returns (bytes32 digest) {
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
    /// @param nonce The nonce of the creator
    /// @param tiers The tiers of the assets
    /// @param amounts The amounts of copies to mint
    /// @param revealed Whether the assets are revealed or not
    /// @param metadataHashes The metadata hashes of the assets
    /// @return digest The hash of the mint batch data
    function _hashBatchMint(
        address creator,
        uint16 nonce,
        uint8[] memory tiers,
        uint256[] memory amounts,
        bool[] memory revealed,
        string[] memory metadataHashes
    ) private view returns (bytes32 digest) {
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

    /// @notice Creates a hash of the lazy mint data
    /// @param creator The address of the creator
    /// @param nonce The nonce of the caller
    /// @param tier The tier of the asset
    /// @param amount The amount of copies to mint
    /// @param metadataHash The metadata hash of the asset
    /// @param maxSupply The max supply of the asset
    /// @param expirationTime The expiration timestamp of the signature
    function _hashLazyMint(
        address caller,
        address creator,
        uint16 nonce,
        uint8 tier,
        uint256 amount,
        uint256 unitPrice,
        address paymentToken,
        string memory metadataHash,
        uint256 maxSupply,
        uint256 expirationTime
    ) private view returns (bytes32 digest) {
        digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    LAZY_MINT_TYPEHASH,
                    caller,
                    creator,
                    nonce,
                    tier,
                    amount,
                    unitPrice,
                    paymentToken,
                    keccak256((abi.encodePacked(metadataHash))),
                    maxSupply,
                    expirationTime
                )
            )
        );
    }

    /// @notice Creates a hash of the lazy mint batch data
    /// @param creators The addresses of the creators
    /// @param nonce The nonce of the caller
    /// @param tiers The tiers of the assets
    /// @param amounts The amounts of copies to mint
    /// @param unitPrices The unit prices of the assets
    /// @param paymentTokens The payment tokens of the assets
    /// @param metadataHashes The metadata hashes of the assets
    /// @param maxSupplies The max supplies of the assets
    /// @param expirationTime The expiration timestamp of the signature
    function _hashLazyBatchMint(
        address caller,
        address[] memory creators,
        uint16 nonce,
        uint8[] memory tiers,
        uint256[] memory amounts,
        uint256[] memory unitPrices,
        address[] memory paymentTokens,
        string[] memory metadataHashes,
        uint256[] memory maxSupplies,
        uint256 expirationTime
    ) private view returns (bytes32 digest) {
        digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    LAZY_MINT_BATCH_TYPEHASH,
                    caller,
                    keccak256(abi.encodePacked(creators)),
                    nonce,
                    keccak256(abi.encodePacked(tiers)),
                    keccak256(abi.encodePacked(amounts)),
                    keccak256(abi.encodePacked(unitPrices)),
                    keccak256(abi.encodePacked(paymentTokens)),
                    _encodeHashes(metadataHashes),
                    keccak256(abi.encodePacked(maxSupplies)),
                    expirationTime
                )
            )
        );
    }

    /// @notice Encodes the hashes of the metadata for signature verification
    /// @param metadataHashes The hashes of the metadata
    /// @return encodedHashes The encoded hashes of the metadata
    function _encodeHashes(string[] memory metadataHashes) private pure returns (bytes32) {
        uint256 arrayLength = metadataHashes.length;
        bytes32[] memory encodedHashes = new bytes32[](arrayLength);
        for (uint256 i; i < arrayLength; ) {
            encodedHashes[i] = keccak256((abi.encodePacked(metadataHashes[i])));
            unchecked {++i;}
        }

        return keccak256(abi.encodePacked(encodedHashes));
    }

    uint256[41] private __gap;
}
