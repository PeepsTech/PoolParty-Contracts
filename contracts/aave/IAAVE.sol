pragma solidity 0.6.12;

interface IAAVE {
    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address token, uint256 amount, address destination) external;
}
