//SPDX-License-Identifier: UNLICENSED
//ALL RIGHTS RESERVED
//apeswap.finance

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract ILOSettings is Ownable {

    struct Settings {
        uint256 BASE_FEE; // base fee divided by 1000
        uint256 TOKEN_FEE; // token fee divided by 1000
        address payable FEE_ADDRESS;
        uint256 ETH_CREATION_FEE; // fee to generate a presale contract on the platform
        uint256 MAX_PRESALE_LENGTH; // maximum difference between start and endblock
    }
    
    Settings public SETTINGS;
    
    constructor() {
        SETTINGS.BASE_FEE = 10; // 1%
        SETTINGS.TOKEN_FEE = 10; // 1%
        SETTINGS.ETH_CREATION_FEE = 1e18;
        SETTINGS.FEE_ADDRESS = payable(msg.sender);
        SETTINGS.MAX_PRESALE_LENGTH = 139569; // 3 weeks
    }

    function getMaxPresaleLength () external view returns (uint256) {
        return SETTINGS.MAX_PRESALE_LENGTH;
    }
    
    function getBaseFee () external view returns (uint256) {
        return SETTINGS.BASE_FEE;
    }
    
    function getTokenFee () external view returns (uint256) {
        return SETTINGS.TOKEN_FEE;
    }
    
    function getEthCreationFee () external view returns (uint256) {
        return SETTINGS.ETH_CREATION_FEE;
    }
    
    function getFeeAddress () external view returns (address payable) {
        return SETTINGS.FEE_ADDRESS;
    }
    
    function setFeeAddresses(address payable _address) external onlyOwner {
        SETTINGS.FEE_ADDRESS = _address;
    }
    
    function setFees(uint256 _baseFee, uint256 _tokenFee, uint256 _ethCreationFee) external onlyOwner {
        SETTINGS.BASE_FEE = _baseFee;
        SETTINGS.TOKEN_FEE = _tokenFee;
        SETTINGS.ETH_CREATION_FEE = _ethCreationFee;
    }

    function setMaxPresaleLength(uint256 _maxLength) external onlyOwner {
        SETTINGS.MAX_PRESALE_LENGTH = _maxLength;
    }    
}