## `IAZOFactory`

Factory to create new IAZOs




### `initialize(contract IIAZO_EXPOSER _iazoExposer, contract IIAZOSettings _iazoSettings, contract IIAZOLiquidityLocker _iazoliquidityLocker, contract IIAZO _iazoInitialImplementation, contract IWNative _wnative, address _admin)` (external)

Initialization of factory




### `createIAZO(address payable _IAZOOwner, contract ERC20 _IAZOToken, contract ERC20 _baseToken, bool _burnRemains, uint256[9] _uint_params)` (public)

Creates new IAZO and adds address to IAZOExposer




### `getHardCap(uint256 _amount, uint256 _tokenPrice, uint256 _decimals) → uint256` (public)

Creates new IAZO and adds address to IAZOExposer




### `getTokensRequired(uint256 _amount, uint256 _tokenPrice, uint256 _listingPrice, uint256 _liquidityPercent, uint256 _decimals) → uint256` (external)

Check for how many tokens are required for the IAZO including token sale and liquidity.




### `getTokensRequiredInternal(uint256 _amount, uint256 _listingPrice, uint256 _liquidityPercent, uint256 _hardcap, uint256 _decimals, uint256 _IAZOTokenFee) → uint256` (internal)





### `pushIAZOVersion(contract IIAZO _newIAZOImplementation)` (public)

Add and use new IAZO implemetation




### `setIAZOVersion(uint256 _newIAZOVersion)` (public)

Use older IAZO implemetation




### `sweepToken(contract IERC20 token)` (external)

A public function to sweep accidental ERC20 transfers to this contract. 
  Tokens are sent to owner





### `IAZOCreated(address newIAZO)`





### `PushIAZOVersion(contract IIAZO newIAZO, uint256 versionId)`





### `UpdateIAZOVersion(uint256 previousVersion, uint256 newVersion)`





### `SweepWithdraw(address receiver, contract IERC20 token, uint256 balance)`





