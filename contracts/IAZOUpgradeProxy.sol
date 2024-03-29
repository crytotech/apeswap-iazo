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

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract IAZOUpgradeProxy is TransparentUpgradeableProxy {
    constructor(
        address admin,
        address logic,
        bytes memory data
    ) TransparentUpgradeableProxy(logic, admin, data) {}
}
