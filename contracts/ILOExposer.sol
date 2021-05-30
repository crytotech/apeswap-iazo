//SPDX-License-Identifier: UNLICENSED
//ALL RIGHTS RESERVED
//apeswap.finance

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract ILOExposer {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private ILOs;

    address ILO_FABRIC;

    event ILORegistered(address presaleContract);

    constructor(address _ILOFabric) {
        ILO_FABRIC = _ILOFabric;
    }

    function registerILO(address _iloAddress) public {
        require(msg.sender == ILO_FABRIC, "Forbidden");
        ILOs.add(_iloAddress);
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
