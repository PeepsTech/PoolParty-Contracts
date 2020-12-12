// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor () internal {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "reentrant call");

        _status = _ENTERED;
        
        _;
        
        _status = _NOT_ENTERED;
    }
}
