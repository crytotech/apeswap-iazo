## `IAZOSettings`

Settings for new IAZOs



### `onlyAdmin()`






### `constructor(address admin, address feeAddress)` (public)





### `getAdminAddress() → address` (external)





### `isAdmin(address toCheck) → bool` (external)





### `getMinStartTime() → uint256` (external)





### `getMaxIAZOLength() → uint256` (external)





### `getMinIAZOLength() → uint256` (external)





### `getBaseFee() → uint256` (external)





### `getIAZOTokenFee() → uint256` (external)





### `getMaxBaseFee() → uint256` (external)





### `getMaxIAZOTokenFee() → uint256` (external)





### `getNativeCreationFee() → uint256` (external)





### `getMinLockPeriod() → uint256` (external)





### `getMinLiquidityPercent() → uint256` (external)





### `getMaxLiquidityPercent() → uint256` (public)





### `getFeeAddress() → address payable` (external)





### `getBurnAddress() → address` (external)





### `setAdminAddress(address _address)` (external)





### `setFeeAddress(address payable _feeAddress)` (external)





### `setFees(uint256 _baseFee, uint256 _iazoTokenFee, uint256 _nativeCreationFee)` (external)



Because liquidity percent and the base fee are taken from the base percentage,
 their combined value cannot be over 100%

### `setStartDelay(uint256 _newStartDelay)` (external)





### `setMaxIAZOLength(uint256 _maxLength)` (external)





### `setMinIAZOLength(uint256 _minLength)` (external)





### `setMinLockPeriod(uint256 _minLockPeriod)` (external)





### `setMinLiquidityPercent(uint256 _minLiquidityPercent)` (external)






### `AdminTransferred(address previousAdmin, address newAdmin)`





### `UpdateFeeAddress(address previousFeeAddress, address newFeeAddress)`





### `UpdateFees(uint256 previousBaseFee, uint256 newBaseFee, uint256 previousIAZOTokenFee, uint256 newIAZOTokenFee, uint256 previousETHFee, uint256 newETHFee)`





### `UpdateStartDelay(uint256 previousStartDelay, uint256 newStartDelay)`





### `UpdateMinIAZOLength(uint256 previousMinLength, uint256 newMinLength)`





### `UpdateMaxIAZOLength(uint256 previousMaxLength, uint256 newMaxLength)`





### `UpdateMinLockPeriod(uint256 previousMinLockPeriod, uint256 newMinLockPeriod)`





### `UpdateMinLiquidityPercent(uint256 previousMinLiquidityPercent, uint256 newMinLiquidityPercent)`





### `UpdateMaxLiquidityPercent(uint256 previousMaxLiquidityPercent, uint256 newMaxLiquidityPercent)`






### `Settings`


address ADMIN_ADDRESS


address payable FEE_ADDRESS


address BURN_ADDRESS


uint256 BASE_FEE


uint256 MAX_BASE_FEE


uint256 IAZO_TOKEN_FEE


uint256 MAX_IAZO_TOKEN_FEE


uint256 NATIVE_CREATION_FEE


uint256 MIN_LIQUIDITY_PERCENT


### `DelaySettings`


uint256 MIN_IAZO_LENGTH


uint256 MAX_IAZO_LENGTH


uint256 MIN_LOCK_PERIOD


uint256 START_DELAY


uint256 MAX_START_DELAY



