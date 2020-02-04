// DAI and ETH have different implements of this method but we require implement this method  
contract SmartFundOverrideInterface {
  function calculateFundValue() public view returns (uint256);
}
