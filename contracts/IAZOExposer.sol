//SPDX-License-Identifier: UNLICENSED
//ALL RIGHTS RESERVED
//apeswap.finance

// TODO: Do we need an indexOf function
// TODO: sweepTokenLib


pragma solidity ^0.8.4;

/*
 * ApeSwapFinance 
 * App:             https://apeswap.finance
 * Medium:          https://ape-swap.medium.com    
 * Twitter:         https://twitter.com/ape_swap 
 * Telegram:        https://t.me/ape_swap
 * Announcements:   https://t.me/ape_swap_news
 * GitHub:          https://github.com/ApeSwapFinance
 */

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

interface IIAZOFabric {
    function isIAZOFabric() external returns (bool);
}

contract IAZOExposer {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private IAZOs;

    address public IAZO_FABRIC;

    bool public isIAZOExposer = true;

    bool private initialized = false;

    event IAZORegistered(address indexed presaleContract);

    function initializeExposer(address iazoFabric) external {
        require(!initialized, "already initialized");
        require(IIAZOFabric(iazoFabric).isIAZOFabric(), "address does not have isIAZOFabric flag");
        IAZO_FABRIC = iazoFabric;
        initialized = true;
    }

    function registerIAZO(address _iazoAddress) external {
        require(initialized, "not initialized");
        require(msg.sender == IAZO_FABRIC, "Forbidden");
        IAZOs.add(_iazoAddress);
        // TODO: Which contract is this supposed to be?
        emit IAZORegistered(_iazoAddress);
    }

    function IAZOIsRegistered(address _iazoAddress)
        external
        view
        returns (bool)
    {
        return IAZOs.contains(_iazoAddress);
    }

    function IAZOAtIndex(uint256 _index) external view returns (address) {
        return IAZOs.at(_index);
    }

    function IAZOsLength() external view returns (uint256) {
        return IAZOs.length();
    }
}
