//SPDX-License-Identifier: UNLICENSED
//ALL RIGHTS RESERVED
//apeswap.finance
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IIAZOSettings.sol";

interface IIAZOTokenTimelock {
    function IAZO_SETTINGS() external view returns (address);

    function isIAZOTokenTimelock() external view returns (bool);

    function initialize(
        IIAZOSettings settings_,
        address beneficiary_,
        uint256 releaseTime_
    ) external;

    function releaseTime() external view returns (uint256);

    function revoked(address) external view returns (bool);

    function numberOfBeneficiaries() external view returns (uint256);

    function beneficiaryAtIndex(uint256 _index) external view returns (address);

    function isBeneficiary(address _address) external view returns (bool);

    function deposit(IERC20 _token, uint256 _amount) external;

    function release(address _token) external;

    function addBeneficiary(address newBeneficiary) external;

    function removeBeneficiary(address beneficiaryToRemove) external;

    function revoke(address _token) external;
}
