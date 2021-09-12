## `IAZOLiquidityLocker`

Locks liquidity on succesful IAZO




### `initialize(address iazoExposer, address apeFactory, address iazoSettings, address admin)` (external)





### `apePairIsInitialised(address _iazoToken, address _baseToken) → bool` (external)

Check if the token pair is initialised or not




### `lockLiquidity(contract IERC20 _baseToken, contract IERC20 _saleToken, uint256 _baseAmount, uint256 _saleAmount, uint256 _unlock_date, address payable _withdrawer, address _iazoAddress) → address` (external)

Lock the liquidity of sale and base tokens




### `sweepToken(contract IERC20 token)` (external)

A public function to sweep accidental ERC20 transfers to this contract. 
  Tokens are sent to owner





### `IAZOLiquidityLocked(address iazo, contract IAZOTokenTimelock iazoTokenlockContract, address pairAddress, uint256 totalLPTokensMinted)`





### `SweepWithdraw(address receiver, contract IERC20 token, uint256 balance)`





