## `IAZO`

IAZO contract where to buy the tokens from



### `onlyAdmin()`

Modifier: Only allow admin address to call certain functions



### `onlyIAZOOwner()`

Modifier: Only allow IAZO owner address to call certain functions



### `onlyIAZOFactory()`

Modifier: Only allow IAZO owner address to call certain functions




### `initialize(address[2] _addresses, address payable[2] _addressesPayable, uint256[12] _uint256s, bool[1] _bools, contract ERC20[2] _ERC20s, contract IWNative _wnative)` (external)

Initialization of IAZO



### `getIAZOState() → uint256` (public)

The state of the IAZO




### `userDepositNative()` (external)

Buy IAZO tokens with native coin



### `userDeposit(uint256 _amount)` (external)

Buy IAZO tokens with base token




### `userWithdraw()` (external)

The function users call to withdraw funds



### `forceFailAdmin()` (external)

onlyAdmin functions



### `updateStart(uint256 _startTime, uint256 _activeTime)` (external)

Change start and end of IAZO




### `updateMaxSpendLimit(uint256 _maxSpend)` (external)

Change the max spend limit for a buyer




### `addLiquidity()` (public)

Final step when IAZO is successfull. lock liquidity and enable withdrawals of sale token.



### `sweepToken(contract IERC20 token)` (external)

A public function to sweep accidental ERC20 transfers to this contract. 
  Tokens are sent to owner





### `ForceFailed(address by)`





### `UpdateMaxSpendLimit(uint256 previousMaxSpend, uint256 newMaxSpend)`





### `FeesCollected(address feeAddress, uint256 baseFeeCollected, uint256 IAZOTokenFee)`





### `UpdateIAZOBlocks(uint256 previousStartTime, uint256 newStartBlock, uint256 previousActiveTime, uint256 newActiveBlocks)`





### `AddLiquidity(uint256 baseLiquidity, uint256 saleTokenLiquidity, uint256 remainingBaseBalance)`





### `SweepWithdraw(address receiver, contract IERC20 token, uint256 balance)`





### `UserWithdrawSuccess(address _address, uint256 _amount)`





### `UserWithdrawFailed(address _address, uint256 _amount)`





### `UserDeposited(address _address, uint256 _amount)`





