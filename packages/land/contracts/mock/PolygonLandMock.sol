// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {AddressUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {PolygonLandBaseToken} from "../polygon/PolygonLandBaseToken.sol";
import {ERC2771Handler} from "../polygon/ERC2771Handler.sol";
import {IOperatorFilterRegistry} from "../polygon/IOperatorFilterRegistry.sol";
import {OperatorFiltererUpgradeable} from "../polygon/OperatorFiltererUpgradeable.sol";
import {IERC2981Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import {IRoyaltyManager} from "@sandbox-smart-contracts/dependency-royalty-management/contracts/interfaces/IRoyaltyManager.sol";

contract PolygonLandMock is PolygonLandBaseToken, ERC2771Handler, OperatorFiltererUpgradeable {
    using AddressUpgradeable for address;

    uint16 internal constant TOTAL_BASIS_POINTS = 10000;

    IRoyaltyManager private royaltyManager;
    address private _owner;

    event OperatorRegistrySet(address indexed registry);
    event RoyaltyManagerSet(address indexed _royaltyManager);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function initialize(
        address trustedForwarder,
        address admin,
        address _royaltyManager,
        address _newOwner
    ) external initializer {
        _admin = admin;
        __ERC2771Handler_initialize(trustedForwarder);
        _setRoyaltyManager(_royaltyManager);
        _transferOwnership(_newOwner);
        emit AdminChanged(address(0), _admin);
    }

    /// @notice set royalty manager
    /// @param _royaltyManager address of royalty manager to set
    function _setRoyaltyManager(address _royaltyManager) internal {
        royaltyManager = IRoyaltyManager(_royaltyManager);
        emit RoyaltyManagerSet(_royaltyManager);
    }

    function _transferOwnership(address _newOwner) internal {
        emit OwnershipTransferred(_owner, _newOwner);
        _owner = _newOwner;
    }

    /// @dev Change the address of the trusted forwarder for meta-TX
    /// @param trustedForwarder The new trustedForwarder
    function setTrustedForwarder(address trustedForwarder) external onlyAdmin {
        _trustedForwarder = trustedForwarder;
        emit TrustedForwarderSet(trustedForwarder);
    }

    /// @notice Returns how much royalty is owed and to whom based on ERC2981
    /// @dev tokenId is one of the EIP2981 args for this function can't be removed
    /// @param _salePrice the price of token on which the royalty is calculated
    /// @return receiver the receiver of royalty
    /// @return royaltyAmount the amount of royalty
    function royaltyInfo(
        uint256 /*_tokenId */,
        uint256 _salePrice
    ) external view returns (address receiver, uint256 royaltyAmount) {
        uint16 royaltyBps;
        (receiver, royaltyBps) = royaltyManager.getRoyaltyInfo();
        royaltyAmount = (_salePrice * royaltyBps) / TOTAL_BASIS_POINTS;
        return (receiver, royaltyAmount);
    }

    /// @notice returns the royalty manager
    /// @return royaltyManagerAddress address of royalty manager contract.
    function getRoyaltyManager() external view returns (IRoyaltyManager royaltyManagerAddress) {
        return royaltyManager;
    }

    /// @notice Get the address of the owner
    /// @return ownerAddress The address of the owner.
    function owner() external view returns (address ownerAddress) {
        return _owner;
    }

    /// @notice Set the address of the new owner of the contract
    /// @param _newOwner address of new owner
    function transferOwnership(address _newOwner) external onlyAdmin {
        _transferOwnership(_newOwner);
    }

    function _msgSender() internal view override(ContextUpgradeable, ERC2771Handler) returns (address) {
        return ERC2771Handler._msgSender();
    }

    function _msgData() internal view override(ContextUpgradeable, ERC2771Handler) returns (bytes calldata) {
        return ERC2771Handler._msgData();
    }

    /**
     * @notice Approve an operator to spend tokens on the sender behalf
     * @param sender The address giving the approval
     * @param operator The address receiving the approval
     * @param id The id of the token
     */
    function approveFor(
        address sender,
        address operator,
        uint256 id
    ) public override onlyAllowedOperatorApproval(operator) {
        super.approveFor(sender, operator, id);
    }

    /**
     * @notice Approve an operator to spend tokens on the sender behalf
     * @param operator The address receiving the approval
     * @param id The id of the token
     */
    function approve(address operator, uint256 id) public override onlyAllowedOperatorApproval(operator) {
        super.approve(operator, id);
    }

    /**
     * @notice Transfer a token between 2 addresses
     * @param from The sender of the token
     * @param to The recipient of the token
     * @param id The id of the token
     */
    function transferFrom(address from, address to, uint256 id) public override onlyAllowedOperator(from) {
        super.transferFrom(from, to, id);
    }

    /**
     * @notice Transfer a token between 2 addresses letting the receiver knows of the transfer
     * @param from The sender of the token
     * @param to The recipient of the token
     * @param id The id of the token
     * @param data Additional data
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes memory data
    ) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, id, data);
    }

    /**
     * @notice Transfer a token between 2 addresses letting the receiver knows of the transfer
     * @param from The send of the token
     * @param to The recipient of the token
     * @param id The id of the token
     */
    function safeTransferFrom(address from, address to, uint256 id) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, id);
    }

    /**
     * @notice Set the approval for an operator to manage all the tokens of the sender
     * @param operator The address receiving the approval
     * @param approved The determination of the approval
     */
    function setApprovalForAll(address operator, bool approved) public override onlyAllowedOperatorApproval(operator) {
        super.setApprovalForAll(operator, approved);
    }

    /**
     * @notice Set the approval for an operator to manage all the tokens of the sender
     * @param sender The address giving the approval
     * @param operator The address receiving the approval
     * @param approved The determination of the approval
     */
    function setApprovalForAllFor(
        address sender,
        address operator,
        bool approved
    ) public override onlyAllowedOperatorApproval(operator) {
        super.setApprovalForAllFor(sender, operator, approved);
    }

    /**
     * @notice Check if the contract supports an interface
     * 0x01ffc9a7 is ERC-165
     * 0x80ac58cd is ERC-721
     * 0x5b5e139f is ERC-721 metadata
     * @param id The id of the interface
     * @return True if the interface is supported
     */
    function supportsInterface(bytes4 id) public pure override(PolygonLandBaseToken) returns (bool) {
        return id == 0x01ffc9a7 || id == 0x80ac58cd || id == 0x5b5e139f || id == type(IERC2981Upgradeable).interfaceId;
    }

    /// @notice This function is used to register Land contract on the Operator Filterer Registry of Opensea.
    /// @dev can only be called by admin.
    /// @param subscriptionOrRegistrantToCopy registration address of the list to subscribe.
    /// @param subscribe bool to signify subscription 'true' or to copy the list 'false'.
    function register(address subscriptionOrRegistrantToCopy, bool subscribe) external onlyAdmin {
        require(subscriptionOrRegistrantToCopy != address(0), "subscription can't be zero");
        _register(subscriptionOrRegistrantToCopy, subscribe);
    }

    /// @notice sets filter registry address deployed in test
    /// @param registry the address of the registry
    function setOperatorRegistry(address registry) external {
        operatorFilterRegistry = IOperatorFilterRegistry(registry);
        emit OperatorRegistrySet(registry);
    }

    /// @notice sets Approvals with operator filterer check in case to test the transfer.
    /// @param operator address of the operator to be approved
    /// @param approved bool value denoting approved (true) or not Approved(false)
    function setApprovalForAllWithOutFilter(address operator, bool approved) external {
        super._setApprovalForAll(msg.sender, operator, approved);
    }

    /**
     * @notice Mint a new quad without a minter (aligned to a quad tree with size 1, 3, 6, 12 or 24 only)
     * @param user The recipient of the new quad
     * @param size The size of the new quad
     * @param x The top left x coordinate of the new quad
     * @param y The top left y coordinate of the new quad
     * @param data extra data to pass to the transfer
     */
    function mintQuad(address user, uint256 size, uint256 x, uint256 y, bytes memory data) external override {
        _mintQuad(user, size, x, y, data);
    }

    /// @notice This function is used to register Land contract on the Operator Filterer Registry of Opensea.can only be called by admin.
    /// @dev used to register contract and subscribe to the subscriptionOrRegistrantToCopy's black list.
    /// @param subscriptionOrRegistrantToCopy registration address of the list to subscribe.
    /// @param subscribe bool to signify subscription "true"" or to copy the list "false".
    function registerFilterer(address subscriptionOrRegistrantToCopy, bool subscribe) external {
        _register(subscriptionOrRegistrantToCopy, subscribe);
    }
}