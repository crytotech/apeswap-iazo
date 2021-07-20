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

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IIAZOFactory {
    function isIAZOFactory() external returns (bool);
}

contract IAZOExposer is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    address public IAZO_FACTORY;

    EnumerableSet.AddressSet private IAZOs;

    mapping(address => uint256) public IAZOAddressToIndex;

    bool public isIAZOExposer = true;

    bool private initialized = false;

    event IAZORegistered(address indexed presaleContract);
    event LogInit();

    function initializeExposer(address iazoFactory) external {
        require(!initialized, "already initialized");
        require(IIAZOFactory(iazoFactory).isIAZOFactory(), "address does not have isIAZOFactory flag");
        IAZO_FACTORY = iazoFactory;
        initialized = true;
        emit LogInit();
    }

    function registerIAZO(address _iazoAddress) external {
        require(initialized, "not initialized");
        require(msg.sender == IAZO_FACTORY, "Forbidden");
        uint256 currentIndex = IAZOsLength();
        bool didAdd = IAZOs.add(_iazoAddress);
        if(didAdd) {
            IAZOAddressToIndex[_iazoAddress] = currentIndex;
            emit IAZORegistered(_iazoAddress);
        }
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

    function IAZOsLength() public view returns (uint256) {
        return IAZOs.length();
    }

    /// @notice A public function to sweep accidental ERC20 transfers to this contract. 
    ///   Tokens are sent to owner
    /// @param token The address of the ERC20 token to sweep
    function sweepToken(IERC20 token) external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        token.transfer(msg.sender, balance);
    }
}
