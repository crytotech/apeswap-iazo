//SPDX-License-Identifier: UNLICENSED
//ALL RIGHTS RESERVED
//apeswap.finance

pragma solidity ^0.8.4;

interface IILOSettings {
    function SETTINGS()
        external
        view
        returns (
            address ADMIN_ADDRESS,
            address FEE_ADDRESS,
            uint256 BASE_FEE,
            uint256 MAX_BASE_FEE,
            uint256 ETH_CREATION_FEE,
            uint256 MIN_ILO_LENGTH,
            uint256 MAX_ILO_LENGTH,
            uint256 MIN_LOCK_PERIOD
        );

    function isILOSettings() external view returns (bool);

    function getAdminAddress() external view returns (address);

    function getMaxILOLength() external view returns (uint256);

    function getMinILOLength() external view returns (uint256);

    function getBaseFee() external view returns (uint256);

    function getMaxBaseFee() external view returns (uint256);

    function getEthCreationFee() external view returns (uint256);

    function getMinLockPeriod() external view returns (uint256);

    function getFeeAddress() external view returns (address payable);

    function setAdminAddress(address _address) external;

    function setFeeAddresses(address _address) external;

    function setFees(uint256 _baseFee, uint256 _ethCreationFee) external;

    function setMaxILOLength(uint256 _maxLength) external;

    function setMinILOLength(uint256 _minLength) external;

    function setMinLockPeriod(uint256 _minLockPeriod) external;
}
