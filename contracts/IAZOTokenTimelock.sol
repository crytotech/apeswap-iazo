// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

/*
 * ApeSwapFinance 
 * App:             https://apeswap.finance
 * Medium:          https://ape-swap.medium.com    
 * Twitter:         https://twitter.com/ape_swap 
 * Telegram:        https://t.me/ape_swap
 * Announcements:   https://t.me/ape_swap_news
 * GitHub:          https://github.com/ApeSwapFinance
 */

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @dev A token holder contract that will allow a beneficiary to extract the
 * tokens after a given release time.
 *
 * Useful for simple vesting schedules like "advisors get all of their tokens
 * after 1 year".
 */
contract IAZOTokenTimelock {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private admins;
    EnumerableSet.AddressSet private beneficiaries;

  struct UserInfo {
    EnumerableSet.AddressSet lockedTokens; // records all tokens the user has locked
    mapping(address => uint256[]) locksForToken; // map erc20 address to lock id for that token
  }
    // flag to verify that this is a token lock contract
    bool public isTokenTimelock = true;
    // timestamp when token release is enabled
    uint256 public releaseTime;
    // beneficiary of tokens after they are released
    bool public revocable;

    mapping(address => bool) public revoked;

    event TokenReleased(address indexed token, uint256 amount);
    event BeneficiaryAdded(address indexed newBeneficiary);
    event Revoked(address token);

    constructor(
        address admin_,
        address beneficiary_,
        uint256 releaseTime_,
        bool revocable_
    ) {
        // TODO: min lock period? 
        admins.add(admin_);
        beneficiaries.add(beneficiary_);
        
        releaseTime = releaseTime_;
        revocable = revocable_;

    }

    modifier onlyAdmin {
        require(
            admins.contains(msg.sender),
            "DOES_NOT_HAVE_ADMIN_ROLE"
        );
        _;
    }

    modifier onlyBeneficiary {
        require(
            beneficiaries.contains(msg.sender),
            "DOES_NOT_HAVE_BENEFICIARY_ROLE"
        );
        _;
    }

    /**
     * @notice Transfers tokens held by timelock to beneficiary.
     */
    function release(IERC20 _token) public virtual onlyBeneficiary {
        require(
            block.timestamp >= releaseTime || revoked[address(_token)],
            "TokenTimelock: current time is before release time or not revoked"
        );

        uint256 amount = _token.balanceOf(address(this));
        require(amount > 0, "TokenTimelock: no tokens to release");

        _token.safeTransfer(msg.sender, amount);
        emit TokenReleased(address(_token), amount);
    }

    /**
     * @notice Transfers tokens held by timelock to beneficiary.
     */
    function addBeneficiary(address newBeneficiary) public virtual onlyBeneficiary {
        beneficiaries.add(newBeneficiary);
        emit BeneficiaryAdded(newBeneficiary);
    }

    /**
     * @notice Allows the owner to revoke the timelock. Tokens already vested
     * @param _token ERC20 token which is being locked
     */
    function revoke(address _token) public onlyAdmin {
        require(revocable, "Contract not revokable");
        require(!revoked[_token], "Already revoked");

        revoked[_token] = true;

        emit Revoked(_token);
    }
}
