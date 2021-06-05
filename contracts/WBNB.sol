//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract WBNB is ERC20 {
    constructor() ERC20("Wrapped BNB", "WBNB") {
        _mint(msg.sender, 2e3 ether);
    }

    function mint(uint256 x) public {
        _mint(msg.sender, x);
    }
}
