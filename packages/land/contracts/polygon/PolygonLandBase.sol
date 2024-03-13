// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {WithAdmin} from "../common/WithAdmin.sol";
import {WithSuperOperators} from "../common/WithSuperOperators.sol";
import {IContext} from "../common/IContext.sol";
import {PolygonLandBaseToken} from "./PolygonLandBaseToken.sol";
import {ERC2771Handler} from "./ERC2771Handler.sol";
import {OperatorFiltererUpgradeable} from "./OperatorFiltererUpgradeable.sol";
import {PolygonLandStorageMixin} from "./PolygonLandStorageMixin.sol";
import {ERC721BaseToken} from "./ERC721BaseToken.sol";

/// @title LAND Base L2
/// @notice This contract composes everything together without adding any functionality (except for _msgSender).
/// @dev We use the storage mixing for historical reasons.
/// @dev There is a difference between L1 and L2 storage slots order and we want to upgrade the contract.
/// @dev This contract uses the exact storage slots configuration that we have in `core` package so we can upgrade
/// @dev It must be the first one in the inheritance chain for subclasses
contract PolygonLandBase is PolygonLandStorageMixin, PolygonLandBaseToken, ERC2771Handler, OperatorFiltererUpgradeable {
    function _msgSender() internal view override(IContext, ContextUpgradeable, ERC2771Handler) returns (address) {
        return ERC2771Handler._msgSender();
    }

    function _msgData() internal view override(ContextUpgradeable, ERC2771Handler) returns (bytes calldata) {
        return ERC2771Handler._msgData();
    }

    function _getAdmin() internal view override(PolygonLandStorageMixin, WithAdmin) returns (address) {
        return PolygonLandStorageMixin._getAdmin();
    }

    function _setAdmin(address a) internal override(PolygonLandStorageMixin, WithAdmin) {
        PolygonLandStorageMixin._setAdmin(a);
    }

    function _isSuperOperator(
        address who
    ) internal view override(PolygonLandStorageMixin, WithSuperOperators) returns (bool) {
        return PolygonLandStorageMixin._isSuperOperator(who);
    }

    function _setSuperOperator(
        address superOperator,
        bool enabled
    ) internal override(PolygonLandStorageMixin, WithSuperOperators) {
        PolygonLandStorageMixin._setSuperOperator(superOperator, enabled);
    }

    function _getNumNFTPerAddress(
        address who
    ) internal view override(PolygonLandStorageMixin, ERC721BaseToken) returns (uint256) {
        return PolygonLandStorageMixin._getNumNFTPerAddress(who);
    }

    function _setNumNFTPerAddress(
        address who,
        uint256 val
    ) internal override(PolygonLandStorageMixin, ERC721BaseToken) {
        PolygonLandStorageMixin._setNumNFTPerAddress(who, val);
    }

    function _getOwnerData(
        uint256 id
    ) internal view override(PolygonLandStorageMixin, ERC721BaseToken) returns (uint256) {
        return PolygonLandStorageMixin._getOwnerData(id);
    }

    function _setOwnerData(uint256 id, uint256 data) internal override(PolygonLandStorageMixin, ERC721BaseToken) {
        PolygonLandStorageMixin._setOwnerData(id, data);
    }
}
