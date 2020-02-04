pragma solidity ^0.4.24;

import "./funds/SmartFundETH.sol";
import "./funds/SmartFundUSD.sol";
import "./interfaces/PermittedExchangesInterface.sol";
import "./interfaces/PermittedPoolsInterface.sol";
import "./interfaces/PermittedStabelsInterface.sol";
import "../../zeppelin-solidity/contracts/ownership/Ownable.sol";

/*
* SmartFundFactory allow create new fund
*/
contract SmartFundFactory is Ownable {
  // The Smart Contract which stores the addresses of all the authorized Exchange Portals
  PermittedExchangesInterface public permittedExchanges;
  // The Smart Contract which stores the addresses of all the authorized Pool Portals
  PermittedPoolsInterface public permittedPools;
  // The Smart Contract which stores the addresses of all the authorized stable coins
  PermittedStabelsInterface public permittedStabels;

  // Addresses of portals
  address public poolPortalAddress;
  address public exchangePortalAddress;

  // Address of stable coin can be set in constructor and changed via function
  address public stableCoinAddress;

  // Address of smart fund registry
  address platformAddress;


  /**
  * @dev contructor
  * @param _platformAddress              Address of the smart fund registry contract
  * @param _permittedExchangesAddress    Address of the permittedExchanges contract
  * @param _exchangePortalAddress        Address of the initial ExchangePortal contract
  * @param _permittedPoolAddress         Address of the permittedPool contract
  * @param _poolPortalAddress            Address of the initial PoolPortal contract
  * @param _permittedStabels             Address of the permittesStabels contract
  * @param _stableCoinAddress            Address of the stable coin
  */
  constructor(
    address _platformAddress,
    address _permittedExchangesAddress,
    address _exchangePortalAddress,
    address _permittedPoolAddress,
    address _poolPortalAddress,
    address _permittedStabels,
    address _stableCoinAddress
  ) public {
    platformAddress = _platformAddress;
    exchangePortalAddress = _exchangePortalAddress;
    permittedExchanges = PermittedExchangesInterface(_permittedExchangesAddress);
    permittedPools = PermittedPoolsInterface(_permittedPoolAddress);
    permittedStabels = PermittedStabelsInterface(_permittedStabels);
    poolPortalAddress = _poolPortalAddress;
    stableCoinAddress = _stableCoinAddress;
  }

  /**
  * @dev Creates a new SmartFund
  *
  * @param _name               The name of the new fund
  * @param _successFee         The fund managers success fee
  * @param _platformFee        Fee of platform
  * @param _isStableBasedFund  true for USD base fund, false for ETH base
  * @param _owner              address of creator fund
  */
  function createSmartFund(
    string _name,
    uint256 _successFee,
    uint256 _platformFee,
    bool _isStableBasedFund,
    address _owner
    )
  public
  returns(address)
  {
    address smartFund;
    if(_isStableBasedFund){
      SmartFundUSD smartFundUSD = new SmartFundUSD(
        _owner,
        _name,
        _successFee,
        _platformFee,
        platformAddress,
        exchangePortalAddress,
        address(permittedExchanges),
        address(permittedPools),
        address(permittedStabels),
        poolPortalAddress,
        stableCoinAddress
      );
      smartFund = address(smartFundUSD);
    }else{
      SmartFundETH smartFundETH = new SmartFundETH(
        _owner,
        _name,
        _successFee,
        _platformFee,
        platformAddress,
        exchangePortalAddress,
        address(permittedExchanges),
        address(permittedPools),
        poolPortalAddress
      );
      smartFund = address(smartFundETH);
    }

    return smartFund;
  }

  /**
  * @dev Sets a new default ExchangePortal address
  *
  * @param _newExchangePortalAddress    Address of the new exchange portal to be set
  */
  function setExchangePortalAddress(address _newExchangePortalAddress) public onlyOwner {
    // Require that the new exchange portal is permitted by permittedExchanges
    require(permittedExchanges.permittedAddresses(_newExchangePortalAddress));
    exchangePortalAddress = _newExchangePortalAddress;
  }

  /**
  * @dev Sets a new default Portal Portal address
  *
  * @param _poolPortalAddress    Address of the new pool portal to be set
  */
  function setPoolPortalAddress (address _poolPortalAddress) external onlyOwner {
    // Require that the new pool portal is permitted by permittedPools
    require(permittedPools.permittedAddresses(_poolPortalAddress));

    poolPortalAddress = _poolPortalAddress;
  }

  /**
  * @dev Sets new stableCoinAddress
  *
  * @param _stableCoinAddress    New stable address
  */
  function changeStableCoinAddress(address _stableCoinAddress) external onlyOwner {
    require(permittedStabels.permittedAddresses(_stableCoinAddress));
    stableCoinAddress = _stableCoinAddress;
  }
}
