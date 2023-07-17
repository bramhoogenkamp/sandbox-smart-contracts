//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {
    AccessControlUpgradeable,
    ContextUpgradeable,
    IAccessControlUpgradeable,
    IERC165Upgradeable
} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {
    ERC1155BurnableUpgradeable,
    ERC1155Upgradeable,
    IERC1155Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";
import {
    ERC1155SupplyUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import {
    ERC1155URIStorageUpgradeable,
    IERC1155MetadataURIUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155URIStorageUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {ERC2771Handler} from "./ERC2771Handler.sol";
import {TokenIdUtils} from "./libraries/TokenIdUtils.sol";
import {IAsset} from "./interfaces/IAsset.sol";

contract Asset is
    IAsset,
    Initializable,
    ERC2771Handler,
    ERC1155BurnableUpgradeable,
    AccessControlUpgradeable,
    ERC1155SupplyUpgradeable,
    ERC1155URIStorageUpgradeable
{
    using TokenIdUtils for uint256;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    // mapping of ipfs metadata token hash to token id
    mapping(string => uint256) public hashUsed;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address forwarder,
        address assetAdmin,
        string memory baseUri
    ) external initializer {
        _setBaseURI(baseUri);
        __AccessControl_init();
        __ERC1155Supply_init();
        __ERC2771Handler_initialize(forwarder);
        __ERC1155Burnable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, assetAdmin);
    }

    /// @notice Mint new tokens
    /// @dev Only callable by the minter role
    /// @param to The address of the recipient
    /// @param id The id of the token to mint
    /// @param amount The amount of the token to mint
    function mint(
        address to,
        uint256 id,
        uint256 amount,
        string memory metadataHash
    ) external onlyRole(MINTER_ROLE) {
        _setMetadataHash(id, metadataHash);
        _mint(to, id, amount, "");
    }

    /// @notice Mint new tokens with catalyst tier chosen by the creator
    /// @dev Only callable by the minter role
    /// @param to The address of the recipient
    /// @param ids The ids of the tokens to mint
    /// @param amounts The amounts of the tokens to mint
    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        string[] memory metadataHashes
    ) external onlyRole(MINTER_ROLE) {
        require(ids.length == metadataHashes.length, "Asset: ids and metadataHash length mismatch");
        require(ids.length == amounts.length, "Asset: ids and amounts length mismatch");
        for (uint256 i = 0; i < ids.length; i++) {
            _setMetadataHash(ids[i], metadataHashes[i]);
        }
        _mintBatch(to, ids, amounts, "");
    }

    /// @notice Burn a token from a given account
    /// @dev Only the minter role can burn tokens
    /// @dev This function was added with token recycling and bridging in mind but may have other use cases
    /// @param account The account to burn tokens from
    /// @param id The token id to burn
    /// @param amount The amount of tokens to burn
    function burnFrom(
        address account,
        uint256 id,
        uint256 amount
    ) external onlyRole(BURNER_ROLE) {
        _burn(account, id, amount);
    }

    /// @notice Burn a batch of tokens from a given account
    /// @dev Only the minter role can burn tokens
    /// @dev This function was added with token recycling and bridging in mind but may have other use cases
    /// @dev The length of the ids and amounts arrays must be the same
    /// @param account The account to burn tokens from
    /// @param ids An array of token ids to burn
    /// @param amounts An array of amounts of tokens to burn
    function burnBatchFrom(
        address account,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external onlyRole(BURNER_ROLE) {
        _burnBatch(account, ids, amounts);
    }

    /// @notice Set a new URI for specific tokenid
    /// @dev The metadata hash should be the IPFS CIDv1 base32 encoded hash
    /// @param tokenId The token id to set URI for
    /// @param metadata The new URI for asset's metadata
    function setTokenURI(uint256 tokenId, string memory metadata) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setMetadataHash(tokenId, metadata);
        _setURI(tokenId, metadata);
    }

    /// @notice Set a new base URI
    /// @param baseURI The new base URI
    function setBaseURI(string memory baseURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setBaseURI(baseURI);
    }

    /// @notice returns full token URI, including baseURI and token metadata URI
    /// @param tokenId The token id to get URI for
    /// @return tokenURI the URI of the token
    function uri(uint256 tokenId)
        public
        view
        override(ERC1155Upgradeable, ERC1155URIStorageUpgradeable)
        returns (string memory)
    {
        return ERC1155URIStorageUpgradeable.uri(tokenId);
    }

    function getTokenIdByMetadataHash(string memory metadataHash) public view returns (uint256) {
        return hashUsed[metadataHash];
    }

    function _setMetadataHash(uint256 tokenId, string memory metadataHash) internal {
        require(
            hasRole(MINTER_ROLE, _msgSender()) || hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "Asset: must have minter or admin role to mint"
        );
        if (hashUsed[metadataHash] != 0) {
            require(hashUsed[metadataHash] == tokenId, "Asset: not allowed to reuse metadata hash");
        } else {
            hashUsed[metadataHash] = tokenId;
            _setURI(tokenId, metadataHash);
        }
    }

    /// @notice Set a new trusted forwarder address, limited to DEFAULT_ADMIN_ROLE only
    /// @dev Change the address of the trusted forwarder for meta-TX
    /// @param trustedForwarder The new trustedForwarder
    function setTrustedForwarder(address trustedForwarder) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(trustedForwarder != address(0), "Asset: trusted forwarder can't be zero address");
        _trustedForwarder = trustedForwarder;
        emit TrustedForwarderChanged(trustedForwarder);
    }

    /// @notice Query if a contract implements interface `id`.
    /// @param id the interface identifier, as specified in ERC-165.
    /// @return `true` if the contract implements `id`.
    function supportsInterface(bytes4 id)
        public
        view
        virtual
        override(ERC1155Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return
            id == type(IERC165Upgradeable).interfaceId ||
            id == type(IERC1155Upgradeable).interfaceId ||
            id == type(IERC1155MetadataURIUpgradeable).interfaceId ||
            id == type(IAccessControlUpgradeable).interfaceId ||
            id == 0x572b6c05; // ERC2771
    }

    function _msgSender() internal view virtual override(ContextUpgradeable, ERC2771Handler) returns (address sender) {
        return ERC2771Handler._msgSender();
    }

    function _msgData() internal view virtual override(ContextUpgradeable, ERC2771Handler) returns (bytes calldata) {
        return ERC2771Handler._msgData();
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155Upgradeable, ERC1155SupplyUpgradeable) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}
