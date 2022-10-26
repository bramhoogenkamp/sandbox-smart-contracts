//SPDX-License-Identifier: MIT
pragma solidity 0.6.5; // TODO: update once upgrade is complete

import "../common/Libraries/SigUtil.sol";
import "../common/Libraries/SafeMathWithRequire.sol";
import "../common/BaseWithStorage/Admin.sol";

contract AuthValidator is Admin {
    address public _signingAuthWallet;

    event SigningWallet(address indexed signingWallet);

    constructor(address adminWallet, address initialSigningWallet) public {
        require(adminWallet != address(0), "AuthValidator: zero address");
        require(initialSigningWallet != address(0), "AuthValidator: zero address");

        _admin = adminWallet;
        _updateSigningAuthWallet(initialSigningWallet);
    }

    function updateSigningAuthWallet(address newSigningWallet) external onlyAdmin {
        _updateSigningAuthWallet(newSigningWallet);
    }

    function _updateSigningAuthWallet(address newSigningWallet) internal {
        require(newSigningWallet != address(0), "AuthValidator: INVALID_SIGNING_WALLET");
        _signingAuthWallet = newSigningWallet;
        emit SigningWallet(newSigningWallet);
    }

    function isAuthValid(bytes memory signature, bytes32 hashedData) public view returns (bool) {
        address signer = SigUtil.recover(keccak256(SigUtil.prefixed(hashedData)), signature);
        return signer == _signingAuthWallet;
    }
}
