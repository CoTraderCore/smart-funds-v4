// due eip-170 error we should create 2 factory one for ETH another for USD
pragma solidity ^0.4.24;

import "./SmartFundUSD.sol";

contract SmartFundUSDFactory {
  address public platfromAddress;

  constructor(address _platfromAddress)public {
    platfromAddress = _platfromAddress;
  }

  function createSmartFund(
    address _owner,
    string  _name,
    uint256 _successFee,
    uint256 _platformFee,
    address _exchangePortalAddress,
    address _permittedExchanges,
    address _permittedPools,
    address _permittedStabels,
    address _poolPortalAddress,
    address _stableCoinAddress
    )
  public
  returns(address)
  {
    require(msg.sender == platfromAddress, "Only portal can create new fund");
    SmartFundUSD smartFundUSD = new SmartFundUSD(
      _owner,
      _name,
      _successFee,
      _platformFee,
      platfromAddress,
      _exchangePortalAddress,
      _permittedExchanges,
      _permittedPools,
      _permittedStabels,
      _poolPortalAddress,
      _stableCoinAddress
    );

    return address(smartFundUSD);
  }
}
