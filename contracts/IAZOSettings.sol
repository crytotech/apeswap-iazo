//SPDX-License-Identifier: UNLICENSED
//ALL RIGHTS RESERVED
//apeswap.finance

pragma solidity 0.8.6;

/*
 * ApeSwapFinance 
 * App:             https://apeswap.finance
 * Medium:          https://ape-swap.medium.com    
 * Twitter:         https://twitter.com/ape_swap 
 * Telegram:        https://t.me/ape_swap
 * Announcements:   https://t.me/ape_swap_news
 * GitHub:          https://github.com/ApeSwapFinance
 */

// TODO: Add a burn address, burn fee and add a burn token
contract IAZOSettings {

    struct Settings {
        address ADMIN_ADDRESS;
        address payable FEE_ADDRESS;
        uint256 BASE_FEE; // base fee percentage
        uint256 MAX_BASE_FEE; // max base fee percentage
        uint256 ETH_CREATION_FEE; // fee to generate a IAZO contract on the platform
        uint256 MIN_IAZO_LENGTH; // minimum iazo active blocks
        uint256 MAX_IAZO_LENGTH; // maximum iazo active blocks
        uint256 MIN_LOCK_PERIOD;
    }

    event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);
    event UpdateFeeAddress(address indexed previousFeeAddress, address indexed newFeeAddress);
    event UpdateFees(uint256 previousBaseFee, uint256 newBaseFee, uint256 previousETHFee, uint256 newETHFee);
    event UpdateMinIAZOLength(uint256 previousMinLength, uint256 newMinLength);
    event UpdateMaxIAZOLength(uint256 previousMaxLength, uint256 newMaxLength);
    event UpdateMinLockPeriod(uint256 previousMinLockPeriod, uint256 newMinLockPeriod);

    Settings public SETTINGS;

    bool public isIAZOSettings = true;
    
    constructor(address admin, address feeAddress) {
        SETTINGS.ADMIN_ADDRESS = admin;
        // TODO: Are we happy with these fees?
        SETTINGS.BASE_FEE = 5;
        SETTINGS.MAX_BASE_FEE = 30; // max base fee percentage
        SETTINGS.ETH_CREATION_FEE = 1e18;
        SETTINGS.FEE_ADDRESS = payable(feeAddress);
        // TODO: Update to 1 hour?
        SETTINGS.MIN_IAZO_LENGTH = 28700; // ~1 day
        SETTINGS.MAX_IAZO_LENGTH = 602700; // ~3 weeks (when 28700 blocks in 1 day) 
        // TODO: Update min lock period?
        // TODO: Do we need to use MIN_LOCK_PERIOD in LiquidityLocker?
        SETTINGS.MIN_LOCK_PERIOD = 28; // in days
    }

    modifier onlyAdmin {
        require(
            msg.sender == SETTINGS.ADMIN_ADDRESS,
            "not called by admin"
        );
        _;
    }

    function getAdminAddress() external view returns (address) {
        return SETTINGS.ADMIN_ADDRESS;
    }

    function isAdmin(address toCheck) external view returns (bool) {
        return SETTINGS.ADMIN_ADDRESS == toCheck;
    }

    function getMaxIAZOLength() external view returns (uint256) {
        return SETTINGS.MAX_IAZO_LENGTH;
    }

    function getMinIAZOLength() external view returns (uint256) {
        return SETTINGS.MIN_IAZO_LENGTH;
    }
    
    function getBaseFee() external view returns (uint256) {
        return SETTINGS.BASE_FEE;
    }

    function getMaxBaseFee() external view returns (uint256) {
        return SETTINGS.MAX_BASE_FEE;
    }
    
    function getEthCreationFee() external view returns (uint256) {
        return SETTINGS.ETH_CREATION_FEE;
    }

    function getMinLockPeriod() external view returns (uint256) {
        return SETTINGS.MIN_LOCK_PERIOD;
    }
    
    function getFeeAddress() external view returns (address payable) {
        return SETTINGS.FEE_ADDRESS;
    }

    function setAdminAddress(address _address) external onlyAdmin {
        address previousAdmin = SETTINGS.ADMIN_ADDRESS;
        SETTINGS.ADMIN_ADDRESS = _address;
        emit AdminTransferred(previousAdmin, SETTINGS.ADMIN_ADDRESS);
    }
    
    function setFeeAddresses(address payable _address) external onlyAdmin {
        address previousFeeAddress = SETTINGS.FEE_ADDRESS;
        SETTINGS.FEE_ADDRESS = _address;
        emit UpdateFeeAddress(previousFeeAddress, SETTINGS.FEE_ADDRESS);
    }
    
    function setFees(uint256 _baseFee, uint256 _ethCreationFee) external onlyAdmin {
        require(_baseFee <= SETTINGS.MAX_BASE_FEE, "base fee over max allowable");
        uint256 previousBaseFee = SETTINGS.BASE_FEE;
        SETTINGS.BASE_FEE = _baseFee;

        uint256 previousETHFee = SETTINGS.ETH_CREATION_FEE;
        SETTINGS.ETH_CREATION_FEE = _ethCreationFee;
        emit UpdateFees(previousBaseFee, SETTINGS.BASE_FEE, previousETHFee, SETTINGS.ETH_CREATION_FEE);
    }

    function setMaxIAZOLength(uint256 _maxLength) external onlyAdmin {
        uint256 previousMaxLength = SETTINGS.MAX_IAZO_LENGTH;
        SETTINGS.MAX_IAZO_LENGTH = _maxLength;
        emit UpdateMaxIAZOLength(previousMaxLength, SETTINGS.MAX_IAZO_LENGTH);
    }  

    function setMinIAZOLength(uint256 _minLength) external onlyAdmin {
        uint256 previousMinLength = SETTINGS.MIN_IAZO_LENGTH;
        SETTINGS.MIN_IAZO_LENGTH = _minLength;
        emit UpdateMinIAZOLength(previousMinLength, SETTINGS.MIN_IAZO_LENGTH);
    }   

    function setMinLockPeriod(uint256 _minLockPeriod) external onlyAdmin {
        uint256 previousMinLockPeriod = SETTINGS.MIN_LOCK_PERIOD;
        SETTINGS.MIN_LOCK_PERIOD = _minLockPeriod;
        emit UpdateMinLockPeriod(previousMinLockPeriod, SETTINGS.MIN_LOCK_PERIOD);
    }    
}