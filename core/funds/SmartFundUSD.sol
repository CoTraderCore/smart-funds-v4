pragma solidity ^0.4.24;

import "./SmartFundCore.sol";
import "../interfaces/SmartFundUSDInterface.sol";
import "../interfaces/PermittedStabelsInterface.sol";


/*
  Note: this smart fund smart fund inherits smart fund core and make core operations like deposit,
  calculate fund value etc in USD
*/
contract SmartFundUSD is SmartFundUSDInterface, Ownable, ERC20, SmartFundCore {
  using SafeMath for uint256;
  using SafeERC20 for ERC20;

  uint public version = 4;

  // Address of stable coin can be set in constructor and changed via function
  address public stableCoinAddress;

  // Total amount of USD deposited by all users
  uint256 public totalUSDDeposited = 0;

  // Total amount of USD withdrawn by all users
  uint256 public totalUSDWithdrawn = 0;

  // The Smart Contract which stores the addresses of all the authorized stable coins
  PermittedStabelsInterface public permittedStabels;

  /**
  * @dev constructor
  *
  * @param _owner                        Address of the fund manager
  * @param _name                         Name of the fund, required for DetailedERC20 compliance
  * @param _successFee                   Percentage of profit that the fund manager receives
  * @param _platformFee                  Percentage of the success fee that goes to the platform
  * @param _platformAddress              Address of platform to send fees to
  * @param _exchangePortalAddress        Address of initial exchange portal
  * @param _permittedExchangesAddress    Address of PermittedExchanges contract
  * @param _permittedPoolsAddress        Address of PermittedPools contract
  * @param _permittedStabels             Address of PermittedStabels contract
  * @param _poolPortalAddress            Address of initial pool portal
  * @param _stableCoinAddress            address of stable coin
  */
  constructor(
    address _owner,
    string _name,
    uint256 _successFee,
    uint256 _platformFee,
    address _platformAddress,
    address _exchangePortalAddress,
    address _permittedExchangesAddress,
    address _permittedPoolsAddress,
    address _permittedStabels,
    address _poolPortalAddress,
    address _stableCoinAddress
  )
  SmartFundCore(
    _owner,
    _name,
    _successFee,
    _platformFee,
    _platformAddress,
    _exchangePortalAddress,
    _permittedExchangesAddress,
    _permittedPoolsAddress,
    _poolPortalAddress
  )
  public {
    // Initial stable coint interface
    permittedStabels = PermittedStabelsInterface(_permittedStabels);
    // Initial stable coin address
    stableCoinAddress = _stableCoinAddress;
    // Push stable coin in tokens list
    tokenAddresses.push(_stableCoinAddress);
  }

  /**
  * @dev Deposits stable soin into the fund and allocates a number of shares to the sender
  * depending on the current number of shares, the funds value, and amount deposited
  *
  * @return The amount of shares allocated to the depositor
  */
  function deposit(uint256 depositAmount) external returns (uint256) {
    // Check if the sender is allowed to deposit into the fund
    if (onlyWhitelist)
      require(whitelist[msg.sender]);

    // Require that the amount sent is not 0
    require(depositAmount > 0);

    // Transfer stable coin from sender
    require(ERC20(stableCoinAddress).transferFrom(msg.sender, address(this), depositAmount));

    totalUSDDeposited += depositAmount;

    // Calculate number of shares
    uint256 shares = calculateDepositToShares(depositAmount);

    // If user would receive 0 shares, don't continue with deposit
    require(shares != 0);

    // Add shares to total
    totalShares = totalShares.add(shares);

    // Add shares to address
    addressToShares[msg.sender] = addressToShares[msg.sender].add(shares);

    addressesNetDeposit[msg.sender] += int256(depositAmount);

    emit Deposit(msg.sender, depositAmount, shares, totalShares);

    return shares;
  }

  /**
  * @dev Withdraws users fund holdings, sends (userShares/totalShares) of every held token
  * to msg.sender, defaults to 100% of users shares.
  *
  * @param _percentageWithdraw    The percentage of the users shares to withdraw.
  */
  function withdraw(uint256 _percentageWithdraw) external {
    require(totalShares != 0);

    uint256 percentageWithdraw = (_percentageWithdraw == 0) ? TOTAL_PERCENTAGE : _percentageWithdraw;

    uint256 addressShares = addressToShares[msg.sender];

    uint256 numberOfWithdrawShares = addressShares.mul(percentageWithdraw).div(TOTAL_PERCENTAGE);

    uint256 fundManagerCut;
    uint256 fundValue;

    // Withdraw the users share minus the fund manager's success fee
    (fundManagerCut, fundValue, ) = calculateFundManagerCut();

    uint256 withdrawShares = numberOfWithdrawShares.mul(fundValue.sub(fundManagerCut)).div(fundValue);

    _withdraw(withdrawShares, totalShares, msg.sender);

    // Store the value we are withdrawing in USD
    uint256 valueWithdrawn = fundValue.mul(withdrawShares).div(totalShares);

    totalUSDWithdrawn = totalUSDWithdrawn.add(valueWithdrawn);
    addressesNetDeposit[msg.sender] -= int256(valueWithdrawn);

    // Subtract from total shares the number of withdrawn shares
    totalShares = totalShares.sub(numberOfWithdrawShares);
    addressToShares[msg.sender] = addressToShares[msg.sender].sub(numberOfWithdrawShares);

    emit Withdraw(msg.sender, numberOfWithdrawShares, totalShares);
  }


  /**
  * @dev Calculates the amount of shares received according to USD deposited
  *
  * @param _amount    Amount of USD to convert to shares
  *
  * @return Amount of shares to be received
  */
  function calculateDepositToShares(uint256 _amount) public view returns (uint256) {
    uint256 fundManagerCut;
    uint256 fundValue;

    // If there are no shares in the contract, whoever deposits owns 100% of the fund
    // we will set this to 10^18 shares, but this could be any amount
    if (totalShares == 0)
      return INITIAL_SHARES;

    (fundManagerCut, fundValue, ) = calculateFundManagerCut();

    uint256 fundValueBeforeDeposit = fundValue.sub(_amount).sub(fundManagerCut);

    if (fundValueBeforeDeposit == 0)
      return 0;

    return _amount.mul(totalShares).div(fundValueBeforeDeposit);

  }


  /**
  * @dev Calculates the funds value in deposit token (USD)
  *
  * @return The current total fund value
  */
  function calculateFundValue() public view returns (uint256) {
    // Convert ETH balance to USD
    uint256 ethBalance = exchangePortal.getValue(
      ETH_TOKEN_ADDRESS,
      stableCoinAddress,
      address(this).balance);

    // If the fund only contains ether, return the funds ether balance converted in USD
    if (tokenAddresses.length == 1)
      return ethBalance;

    // Otherwise, we get the value of all the other tokens in ether via exchangePortal

    // Calculate value for ERC20
    address[] memory fromAddresses = new address[](tokenAddresses.length - 1);
    uint256[] memory amounts = new uint256[](tokenAddresses.length - 1);

    for (uint256 i = 1; i < tokenAddresses.length; i++) {
      fromAddresses[i-1] = tokenAddresses[i];
      amounts[i-1] = ERC20(tokenAddresses[i]).balanceOf(address(this));
    }

    // Ask the Exchange Portal for the value of all the funds tokens in stable coin
    uint256 tokensValue = exchangePortal.getTotalValue(fromAddresses, amounts, stableCoinAddress);

    // Sum ETH + ERC20
    return ethBalance + tokensValue;
  }


  /**
  * @dev Calculates the fund managers cut, depending on the funds profit and success fee
  *
  * @return fundManagerRemainingCut    The fund managers cut that they have left to withdraw
  * @return fundValue                  The funds current value
  * @return fundManagerTotalCut        The fund managers total cut of the profits until now
  */
  function calculateFundManagerCut() public view returns (
    uint256 fundManagerRemainingCut, // fm's cut of the profits that has yet to be cashed out (in `depositToken`)
    uint256 fundValue, // total value of fund (in `depositToken`)
    uint256 fundManagerTotalCut // fm's total cut of the profits (in `depositToken`)
  ) {
    fundValue = calculateFundValue();
    // The total amount of USD currently deposited into the fund, takes into account the total USD
    // withdrawn by investors as well as USD withdrawn by the fund manager
    // NOTE: value can be negative if the manager performs well and investors withdraw more
    // USD than they deposited
    int256 curTotalUSDDeposited = int256(totalUSDDeposited) - int256(totalUSDWithdrawn.add(fundManagerCashedOut));

    // If profit < 0, the fund managers totalCut and remainingCut are 0
    if (int256(fundValue) <= curTotalUSDDeposited) {
      fundManagerTotalCut = 0;
      fundManagerRemainingCut = 0;
    } else {
      // calculate profit. profit = current fund value - total deposited + total withdrawn + total withdrawn by fm
      uint256 profit = uint256(int256(fundValue) - curTotalUSDDeposited);
      // remove the money already taken by the fund manager and take percentage
      fundManagerTotalCut = profit.mul(successFee).div(TOTAL_PERCENTAGE);
      fundManagerRemainingCut = fundManagerTotalCut.sub(fundManagerCashedOut);
    }
  }

  /**
  * @dev Allows the fund manager to withdraw their cut of the funds profit
  */
  function fundManagerWithdraw() public onlyOwner {
    uint256 fundManagerCut;
    uint256 fundValue;

    (fundManagerCut, fundValue, ) = calculateFundManagerCut();

    uint256 platformCut = (platformFee == 0) ? 0 : fundManagerCut.mul(platformFee).div(TOTAL_PERCENTAGE);

    _withdraw(platformCut, fundValue, platformAddress);
    _withdraw(fundManagerCut - platformCut, fundValue, msg.sender);

    fundManagerCashedOut = fundManagerCashedOut.add(fundManagerCut);
  }

  // calculate the current value of an address's shares in the fund
  function calculateAddressValue(address _address) public view returns (uint256) {
    if (totalShares == 0)
      return 0;

    return calculateFundValue().mul(addressToShares[_address]).div(totalShares);
  }

  // calculate the net profit/loss for an address in this fund
  function calculateAddressProfit(address _address) public view returns (int256) {
    uint256 currentAddressValue = calculateAddressValue(_address);

    return int256(currentAddressValue) - addressesNetDeposit[_address];
  }

  /**
  * @dev Calculates the funds profit
  *
  * @return The funds profit in deposit token (USD)
  */
  function calculateFundProfit() public view returns (int256) {
    uint256 fundValue = calculateFundValue();

    return int256(fundValue) + int256(totalUSDWithdrawn) - int256(totalUSDDeposited);
  }
}
