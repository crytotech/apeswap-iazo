## `IAZOFactory`

Factory to create new IAZOs


This contract currently does NOT support non-standard ERC-20 tokens with fees on transfers


### `initialize(contract IIAZO_EXPOSER _iazoExposer, contract IIAZOSettings _iazoSettings, contract IIAZOLiquidityLocker _iazoliquidityLocker, contract IIAZO _iazoInitialImplementation, contract IWNative _wnative, address _admin)` (external)

Initialization of factory




### `createIAZO(address payable _IAZOOwner, contract ERC20 _IAZOToken, contract ERC20 _baseToken, bool _burnRemains, uint256[9] _uint_params)` (external)

Creates new IAZO and adds address to IAZOExposer




### `getHardCap(uint256 _amount, uint256 _tokenPrice) → uint256` (public)

Creates new IAZO and adds address to IAZOExposer




### `getTokensRequired(uint256 _amount, uint256 _tokenPrice, uint256 _listingPrice, uint256 _liquidityPercent) → uint256` (external)

Check for how many tokens are required for the IAZO including token sale and liquidity.




### `_getTokensRequired(uint256 _amount, uint256 _tokenPrice, uint256 _listingPrice, uint256 _liquidityPercent, uint256 _iazoTokenFee, bool _require) → uint256` (internal)





### `pushIAZOVersion(contract IIAZO _newIAZOImplementation)` (external)

Add and use new IAZO implementation




### `setIAZOVersion(uint256 _newIAZOVersion)` (external)

Use older IAZO implementation


Owner should be behind a timelock to prevent front running new IAZO deployments


### `sweepTokens(contract IERC20[] _tokens, address _to)` (external)

A public function to sweep accidental ERC20 transfers to this contract. 





### `IAZOCreated(address newIAZO)`





### `PushIAZOVersion(contract IIAZO newIAZO, uint256 versionId)`





### `UpdateIAZOVersion(uint256 previousVersion, uint256 newVersion)`





### `SweepWithdraw(address receiver, contract IERC20 token, uint256 balance)`






### `IAZOParams`


uint256 TOKEN_PRICE


uint256 AMOUNT


uint256 HARDCAP


uint256 SOFTCAP


uint256 START_TIME


uint256 ACTIVE_TIME


uint256 LOCK_PERIOD


uint256 MAX_SPEND_PER_BUYER


uint256 LIQUIDITY_PERCENT


uint256 LISTING_PRICE



