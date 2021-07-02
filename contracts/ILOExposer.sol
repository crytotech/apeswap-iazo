//SPDX-License-Identifier: UNLICENSED
//ALL RIGHTS RESERVED
//apeswap.finance

// TODO: Do we need an indexOf function
// TODO: sweepTokenLib


pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

interface IILOFabric {
    function isILOFabric() external returns (bool);
}

contract ILOExposer {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private ILOs;

    address public ILO_FABRIC;

    bool public isILOExposer = true;

    bool private initialized = false;

    event ILORegistered(address indexed presaleContract);

    function initializeExposer(address iloFabric) external {
        require(!initialized, "already initialized");
        require(IILOFabric(iloFabric).isILOFabric(), "address does not have isILOFabric flag");
        ILO_FABRIC = iloFabric;
        initialized = true;
    }

    function registerILO(address _iloAddress) external {
        require(initialized, "not initialized");
        require(msg.sender == ILO_FABRIC, "Forbidden");
        ILOs.add(_iloAddress);
        // TODO: Which contract is this supposed to be?
        emit ILORegistered(_iloAddress);
    }

    function ILOIsRegistered(address _iloAddress)
        external
        view
        returns (bool)
    {
        return ILOs.contains(_iloAddress);
    }

    function ILOAtIndex(uint256 _index) external view returns (address) {
        return ILOs.at(_index);
    }

    function ILOsLength() external view returns (uint256) {
        return ILOs.length();
    }
}
