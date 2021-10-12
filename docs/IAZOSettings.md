## `IAZOSettings`

Settings for new IAZOs



### `onlyAdmin()`






### `constructor(address admin, address feeAddress)` (public)





### `getAdminAddress() → address` (external)





### `isAdmin(address toCheck) → bool` (external)





### `getMaxIAZOLength() → uint256` (external)





### `getMinIAZOLength() → uint256` (external)





### `getBaseFee() → uint256` (external)





### `getIAZOTokenFee() → uint256` (external)





### `getMaxBaseFee() → uint256` (external)





### `getMaxIAZOTokenFee() → uint256` (external)





### `getNativeCreationFee() → uint256` (external)





### `getMinLockPeriod() → uint256` (external)





### `getMinLiquidityPercent() → uint256` (external)





### `getFeeAddress() → address payable` (external)





### `getBurnAddress() → address` (external)





### `setAdminAddress(address _address)` (external)





### `setFeeAddress(address payable _feeAddress)` (external)





### `setFees(uint256 _baseFee, uint256 _iazoTokenFee, uint256 _nativeCreationFee)` (external)





### `setMaxIAZOLength(uint256 _maxLength)` (external)





### `setMinIAZOLength(uint256 _minLength)` (external)





### `setMinLockPeriod(uint256 _minLockPeriod)` (external)





### `setMinLiquidityPercent(uint256 _minLiquidityPercent)` (external)






### `AdminTransferred(address previousAdmin, address newAdmin)`





### `UpdateFeeAddress(address previousFeeAddress, address newFeeAddress)`





### `UpdateFees(uint256 previousBaseFee, uint256 newBaseFee, uint256 previousIAZOTokenFee, uint256 newIAZOTokenFee, uint256 previousETHFee, uint256 newETHFee)`





### `UpdateMinIAZOLength(uint256 previousMinLength, uint256 newMinLength)`





### `UpdateMaxIAZOLength(uint256 previousMaxLength, uint256 newMaxLength)`





### `UpdateMinLockPeriod(uint256 previousMinLockPeriod, uint256 newMinLockPeriod)`





### `UpdateMinLiquidityPercent(uint256 previousMinLiquidityPercent, uint256 newMinLiquidityPercent)`





