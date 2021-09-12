## `IAZOTokenTimelock`



A token holder contract that will allow a beneficiary to extract the
tokens after a given release time.

Useful for simple vesting schedules like "advisors get all of their tokens
after 1 year".

### `onlyAdmin()`





### `onlyBeneficiary()`






### `constructor(contract IIAZOSettings settings_, address beneficiary_, uint256 releaseTime_, bool revocable_)` (public)





### `numberOfBeneficiaries() → uint256` (external)





### `beneficiaryAtIndex(uint256 _index) → address` (external)





### `isBeneficiary(address _address) → bool` (public)





### `deposit(contract IERC20 _token, uint256 _amount)` (external)





### `release(contract IERC20 _token)` (external)

Transfers tokens held by timelock to beneficiary.



### `addBeneficiary(address newBeneficiary)` (external)

Add an address that is eligible to unlock tokens.



### `addBeneficiaryInternal(address newBeneficiary)` (internal)

Add an address that is eligible to unlock tokens.



### `revoke(address _token)` (external)

Allows the owner to revoke the timelock. Tokens already vested





### `Deposit(contract IERC20 token, uint256 amount)`





### `TokenReleased(contract IERC20 token, uint256 amount)`





### `BeneficiaryAdded(address newBeneficiary)`





### `Revoked(address token)`





