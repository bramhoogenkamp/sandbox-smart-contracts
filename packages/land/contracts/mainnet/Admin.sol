// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

contract Admin {
    address internal _admin;

    event AdminChanged(address oldAdmin, address newAdmin);

    /// @notice gives the current administrator of this contract.
    /// @return the current administrator of this contract.
    function getAdmin() external view returns (address) {
        return _admin;
    }

    /// @notice change the administrator to be `newAdmin`.
    /// @param newAdmin address of the new administrator.
    function changeAdmin(address newAdmin) external {
        address admin = _admin;
        require(msg.sender == admin, "only admin can change admin");
        require(newAdmin != admin, "only new admin");
        emit AdminChanged(admin, newAdmin);
        _admin = newAdmin;
    }

    modifier onlyAdmin() {
        require(msg.sender == _admin, "only admin allowed");
        _;
    }
}
