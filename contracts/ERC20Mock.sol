//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    constructor() ERC20("ERC20 Mock", "MOCK") {
        _mint(msg.sender, 2e3 ether);
    }

    function mint(uint256 x) public {
        _mint(msg.sender, x);
    }

    function burn(uint256 x) public {
        _burn(msg.sender, x);
    }

    function burnAll() public {
        _burn(msg.sender, balanceOf(msg.sender));
    }
}
