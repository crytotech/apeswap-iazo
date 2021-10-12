## `IAZOExposer`

Keeps track of all created IAZOs and exposes to outside world




### `initializeExposer(address _iazoFactory, address _liquidityLocker)` (external)

Initialization of exposer




### `registerIAZO(address _iazoAddress)` (external)

Registers new IAZO address




### `IAZOIsRegistered(address _iazoAddress) → bool` (external)

Check for IAZO registration




### `addTokenTimelock(address _iazoAddress, address _iazoTokenTimelock)` (external)

Registers token timelock address and links with corresponding IAZO




### `getTokenTimelock(address _iazoAddress) → address` (external)

Returns the token timelock address based on IAZO address




### `IAZOAtIndex(uint256 _index) → address` (external)

Returns the IAZO based on index of creation




### `IAZOsLength() → uint256` (public)

Amount of IAZOs created total




### `sweepTokens(contract IERC20[] _tokens, address _to)` (external)

A public function to sweep accidental ERC20 transfers to this contract. 





### `IAZORegistered(address IAZOContract)`





### `IAZOTimelockAdded(address IAZOContract, address TimelockContract)`





### `LogInit()`





### `SweepWithdraw(address _to, contract IERC20 token, uint256 balance)`





