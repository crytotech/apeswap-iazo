//SPDX-License-Identifier: UNLICENSED
//ALL RIGHTS RESERVED
//apeswap.finance

pragma solidity ^0.8.4;

// TODO: Add a burn address, burn fee and add a burn token
contract ILOSettings {

    struct Settings {
        address ADMIN_ADDRESS;
        address payable FEE_ADDRESS;
        uint256 BASE_FEE; // base fee percentage
        uint256 MAX_BASE_FEE; // max base fee percentage
        uint256 ETH_CREATION_FEE; // fee to generate a ILO contract on the platform
        uint256 MIN_ILO_LENGTH; // minimum ilo active blocks
        uint256 MAX_ILO_LENGTH; // maximum ilo active blocks
        uint256 MIN_LOCK_PERIOD;
    }

    event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);
    event UpdateFeeAddress(address indexed previousFeeAddress, address indexed newFeeAddress);
    event UpdateFees(uint256 previousBaseFee, uint256 newBaseFee, uint256 previousETHFee, uint256 newETHFee);
    event UpdateMinILOLength(uint256 previousMinLength, uint256 newMinLength);
    event UpdateMaxILOLength(uint256 previousMaxLength, uint256 newMaxLength);
    event UpdateMinLockPeriod(uint256 previousMinLockPeriod, uint256 newMinLockPeriod);

    Settings public SETTINGS;

    bool public isILOSettings = true;
    
    constructor(address admin, address feeAddress) {
        SETTINGS.ADMIN_ADDRESS = admin;
        // TODO: Maybe add more decimals for greater flexbility?
        SETTINGS.BASE_FEE = 5;
        // TODO: Review MAX_BASE_FEE with team
        SETTINGS.MAX_BASE_FEE = 30; // max base fee percentage
        SETTINGS.ETH_CREATION_FEE = 1e18;
        // FIXME: pass fee-address into constructor? Currently msg.sender is a contract
        SETTINGS.FEE_ADDRESS = payable(feeAddress);
        // TODO: Update to 1 hour?
        SETTINGS.MIN_ILO_LENGTH = 28700; // ~1 day
        SETTINGS.MAX_ILO_LENGTH = 602700; // ~3 weeks (when 28700 blocks in 1 day) 
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

    function getMaxILOLength() external view returns (uint256) {
        return SETTINGS.MAX_ILO_LENGTH;
    }

    function getMinILOLength() external view returns (uint256) {
        return SETTINGS.MIN_ILO_LENGTH;
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

    function setMaxILOLength(uint256 _maxLength) external onlyAdmin {
        uint256 previousMaxLength = SETTINGS.MAX_ILO_LENGTH;
        SETTINGS.MAX_ILO_LENGTH = _maxLength;
        emit UpdateMaxILOLength(previousMaxLength, SETTINGS.MAX_ILO_LENGTH);
    }  

    function setMinILOLength(uint256 _minLength) external onlyAdmin {
        uint256 previousMinLength = SETTINGS.MIN_ILO_LENGTH;
        SETTINGS.MIN_ILO_LENGTH = _minLength;
        emit UpdateMinILOLength(previousMinLength, SETTINGS.MIN_ILO_LENGTH);
    }   

    function setMinLockPeriod(uint256 _minLockPeriod) external onlyAdmin {
        uint256 previousMinLockPeriod = SETTINGS.MIN_LOCK_PERIOD;
        SETTINGS.MIN_LOCK_PERIOD = _minLockPeriod;
        emit UpdateMinLockPeriod(previousMinLockPeriod, SETTINGS.MIN_LOCK_PERIOD);
    }    
}