//SPDX-License-Identifier: UNLICENSED
//ALL RIGHTS RESERVED
//apeswap.finance

pragma solidity 0.8.6;

interface IIAZOSettings {
    function SETTINGS()
        external
        view
        returns (
            address ADMIN_ADDRESS,
            address payable FEE_ADDRESS,
            address BURN_ADDRESS,
            uint256 BASE_FEE, // base fee percentage
            uint256 MAX_BASE_FEE, // max base fee percentage
            uint256 IAZO_TOKEN_FEE, // base fee percentage
            uint256 MAX_IAZO_TOKEN_FEE, // max base fee percentage
            uint256 NATIVE_CREATION_FEE, // fee to generate a IAZO contract on the platform
            uint256 MIN_LIQUIDITY_PERCENT,
            uint256 MAX_LIQUIDITY_PERCENT
        );
    
    function DELAY_SETTINGS()
        external
        view
        returns (
            uint256 MIN_IAZO_LENGTH, // minimum iazo active seconds
            uint256 MAX_IAZO_LENGTH, // maximum iazo active seconds
            uint256 MIN_LOCK_PERIOD,
            uint256 START_DELAY, // minium time away from creation that the iazo can start
            uint256 MAX_START_DELAY // minium time away from creation that the iazo can start
        );

    function isIAZOSettings() external view returns (bool);

    function getAdminAddress() external view returns (address);

    function isAdmin(address toCheck) external view returns (bool);

    function getMinStartTime() external view returns (uint256);

    function getMaxIAZOLength() external view returns (uint256);

    function getMinIAZOLength() external view returns (uint256);

    function getBaseFee() external view returns (uint256);

    function getIAZOTokenFee() external view returns (uint256);
    
    function getMaxBaseFee() external view returns (uint256);

    function getMaxIAZOTokenFee() external view returns (uint256);

    function getNativeCreationFee() external view returns (uint256);

    function getMinLockPeriod() external view returns (uint256);

    function getMinLiquidityPercent() external view returns (uint256);

    function getMaxLiquidityPercent() external view returns (uint256);

    function getFeeAddress() external view returns (address payable);

    function getBurnAddress() external view returns (address);

    function setAdminAddress(address _address) external;

    function setFeeAddresses(address _address) external;

    function setFees(uint256 _baseFee, uint256 _iazoTokenFee, uint256 _nativeCreationFee) external;

    function setStartDelay(uint256 _maxLength) external;

    function setMaxIAZOLength(uint256 _maxLength) external;

    function setMinIAZOLength(uint256 _minLength) external;

    function setMinLockPeriod(uint256 _minLockPeriod) external;

    function setMinLiquidityPercent(uint256 _minLiquidityPercent) external;

    function setMaxLiquidityPercent(uint256 _maxLiquidityPercent) external;

    function setBurnAddress(address _burnAddress) external;

}
