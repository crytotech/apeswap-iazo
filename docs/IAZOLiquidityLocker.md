## `IAZOLiquidityLocker`

Locks liquidity on successful IAZO




### `initialize(address iazoExposer, address apeFactory, address iazoSettings, address admin, address initialTokenTimelockImplementation)` (external)





### `apePairIsInitialized(address _iazoToken, address _baseToken) → bool` (external)

Check if the token pair is initialized or not




### `lockLiquidity(contract IERC20 _baseToken, contract IERC20 _saleToken, uint256 _baseAmount, uint256 _saleAmount, uint256 _unlockDate, address payable _withdrawer) → address` (external)

Lock the liquidity of sale and base tokens


The IIAZOTokenTimelock can have tokens revoked to be released early by the admin. This is a 
 safety mechanism in case the wrong tokens are sent to the contract.


### `sweepTokens(contract IERC20[] _tokens, address _to)` (external)

A public function to sweep accidental ERC20 transfers to this contract. 





### `IAZOLiquidityLocked(address iazo, contract IIAZOTokenTimelock iazoTokenlockContract, address pairAddress, uint256 totalLPTokensMinted)`





### `SweepWithdraw(address receiver, contract IERC20 token, uint256 balance)`





