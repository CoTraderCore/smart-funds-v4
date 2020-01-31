pragma solidity ^0.4.24;

contract PermittedExchangesInterface {
  mapping (address => bool) public permittedAddresses;
}
