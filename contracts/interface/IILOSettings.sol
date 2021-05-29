//SPDX-License-Identifier: UNLICENSED
//ALL RIGHTS RESERVED
//apeswap.finance

pragma solidity ^0.8.0;

interface IILOSettings {
    function getMaxPresaleLength() external view returns (uint256);

    function getBaseFee() external view returns (uint256);

    function getTokenFee() external view returns (uint256);

    function getEthCreationFee() external view returns (uint256);

    function getFeeAddress() external view returns (address payable);

    function setFeeAddresses(address payable _address) external;

    function setFees(
        uint256 _baseFee,
        uint256 _tokenFee,
        uint256 _ethCreationFee
    ) external;

    function setMaxPresaleLength(uint256 _maxLength) external;
}
