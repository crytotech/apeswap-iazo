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


This contract should not be deployed without the factory as important safety checks are made before deployment


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




### `withdrawOfferTokensOnFailure()` (external)

IAZO Owner can pull out offer tokens on failure



### `addLiquidity() → bool` (public)

Final step when IAZO is successful. lock liquidity and enable withdrawals of sale token.



### `sweepTokens(contract ERC20[] _tokens, address _to)` (external)

A public function to sweep accidental ERC20 transfers to this contract. 





### `ForceFailed(address by)`





### `UpdateMaxSpendLimit(uint256 previousMaxSpend, uint256 newMaxSpend)`





### `FeesCollected(address feeAddress, uint256 baseFeeCollected, uint256 IAZOTokenFee)`





### `UpdateIAZOBlocks(uint256 previousStartTime, uint256 newStartBlock, uint256 previousActiveTime, uint256 newActiveBlocks)`





### `AddLiquidity(uint256 baseLiquidity, uint256 saleTokenLiquidity, uint256 remainingBaseBalance)`





### `SweepWithdraw(address receiver, contract IERC20 token, uint256 balance)`





### `UserWithdrawSuccess(address _address, uint256 _amount)`





### `UserWithdrawFailed(address _address, uint256 _amount)`





### `UserDeposited(address _address, uint256 _amount)`






### `IAZOInfo`


address payable IAZO_OWNER


contract ERC20 IAZO_TOKEN


contract ERC20 BASE_TOKEN


bool IAZO_SALE_IN_NATIVE


uint256 TOKEN_PRICE


uint256 AMOUNT


uint256 HARDCAP


uint256 SOFTCAP


uint256 MAX_SPEND_PER_BUYER


uint256 LIQUIDITY_PERCENT


uint256 LISTING_PRICE


bool BURN_REMAINS


### `IAZOTimeInfo`


uint256 START_TIME


uint256 ACTIVE_TIME


uint256 LOCK_PERIOD


### `IAZOStatus`


bool LP_GENERATION_COMPLETE


bool FORCE_FAILED


uint256 TOTAL_BASE_COLLECTED


uint256 TOTAL_TOKENS_SOLD


uint256 TOTAL_TOKENS_WITHDRAWN


uint256 TOTAL_BASE_WITHDRAWN


uint256 NUM_BUYERS


### `BuyerInfo`


uint256 deposited


uint256 tokensBought


### `FeeInfo`


address payable FEE_ADDRESS


uint256 BASE_FEE


uint256 IAZO_TOKEN_FEE



