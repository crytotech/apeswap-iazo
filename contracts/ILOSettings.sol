//SPDX-License-Identifier: UNLICENSED
//ALL RIGHTS RESERVED
//apeswap.finance

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";

contract ILOSettings is Ownable {

    struct Settings {
        address ADMIN_ADDRESS;
        address payable FEE_ADDRESS;
        uint256 BASE_FEE; // base fee percentage
        uint256 ETH_CREATION_FEE; // fee to generate a ILO contract on the platform
        uint256 MIN_ILO_LENGTH; // minimum ilo active blocks
        uint256 MAX_ILO_LENGTH; // maximum ilo active blocks
        uint256 MIN_LOCK_PERIOD;
    }
    
    Settings public SETTINGS;
    
    constructor() {
        SETTINGS.ADMIN_ADDRESS = 0x53C011Cd7F4FCab2C97EF2a1d7c0A60d6d4bA0C4;
        SETTINGS.BASE_FEE = 5;
        SETTINGS.ETH_CREATION_FEE = 1e18;
        SETTINGS.FEE_ADDRESS = payable(msg.sender);
        SETTINGS.MIN_ILO_LENGTH = 28700; // ~1 day
        SETTINGS.MAX_ILO_LENGTH = 602700; // ~3 weeks (when 28700 blocks in 1 day) 
        SETTINGS.MIN_LOCK_PERIOD = 28; // in days
    }

    function getAdminAddress() external view returns (address) {
        return SETTINGS.ADMIN_ADDRESS;
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
    
    function getEthCreationFee() external view returns (uint256) {
        return SETTINGS.ETH_CREATION_FEE;
    }

    function getMinLockPeriod() external view returns (uint256) {
        return SETTINGS.MIN_LOCK_PERIOD;
    }
    
    function getFeeAddress() external view returns (address payable) {
        return SETTINGS.FEE_ADDRESS;
    }

    function setAdminAddress(address _address) external onlyOwner {
        SETTINGS.ADMIN_ADDRESS = _address;
    }
    
    function setFeeAddresses(address payable _address) external onlyOwner {
        SETTINGS.FEE_ADDRESS = _address;
    }
    
    function setFees(uint256 _baseFee, uint256 _ethCreationFee) external onlyOwner {
        SETTINGS.BASE_FEE = _baseFee;
        SETTINGS.ETH_CREATION_FEE = _ethCreationFee;
    }

    function setMaxILOLength(uint256 _maxLength) external onlyOwner {
        SETTINGS.MAX_ILO_LENGTH = _maxLength;
    }  

    function setMinILOLength(uint256 _minLength) external onlyOwner {
        SETTINGS.MIN_ILO_LENGTH = _minLength;
    }   

    function setMinLockPeriod(uint256 _minLockPeriod) external onlyOwner {
        SETTINGS.MIN_LOCK_PERIOD = _minLockPeriod;
    }    
}