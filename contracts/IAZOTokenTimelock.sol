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

import "./interface/IIAZOSettings.sol";

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

    EnumerableSet.AddressSet private beneficiaries;

  struct UserInfo {
    EnumerableSet.AddressSet lockedTokens; // records all tokens the user has locked
    mapping(address => uint256[]) locksForToken; // map erc20 address to lock id for that token
  }
    IIAZOSettings public IAZO_SETTINGS;

    // flag to verify that this is a token lock contract
    bool public isIAZOTokenTimelock = true;
    // timestamp when token release is enabled
    uint256 public releaseTime;
    // beneficiary of tokens after they are released
    bool public revocable;

    mapping(address => bool) public revoked;

    event Deposit(IERC20 indexed token, uint256 amount);
    event TokenReleased(IERC20 indexed token, uint256 amount);
    event BeneficiaryAdded(address indexed newBeneficiary);
    event Revoked(address token);

    constructor(
        IIAZOSettings settings_,
        address beneficiary_,
        uint256 releaseTime_,
        bool revocable_
    ) {
        IAZO_SETTINGS = settings_;
        addBeneficiaryInternal(beneficiary_);
        
        releaseTime = releaseTime_;
        revocable = revocable_;

    }

    modifier onlyAdmin {
        require(
            msg.sender == IAZO_SETTINGS.getAdminAddress(),
            "DOES_NOT_HAVE_ADMIN_ROLE"
        );
        _;
    }

    modifier onlyBeneficiary {
        require(
            isBeneficiary(msg.sender),
            "DOES_NOT_HAVE_BENEFICIARY_ROLE"
        );
        _;
    }

    function numberOfBeneficiaries() external view returns (uint256) {
        return beneficiaries.length();
    }

    function beneficiaryAtIndex(uint256 _index) external view returns (address) {
        return beneficiaries.at(_index);
    }

    function isBeneficiary(address _address) public view returns (bool) {
        return beneficiaries.contains(_address);
    }

    function deposit(IERC20 _token, uint256 _amount) external {
        _token.safeTransferFrom(msg.sender, address(this), _amount);
        emit Deposit(_token, _amount);
    }

    /**
     * @notice Transfers tokens held by timelock to beneficiary.
     */
    function release(IERC20 _token) external onlyBeneficiary {
        require(
            block.timestamp >= releaseTime || revoked[address(_token)],
            "TokenTimelock: current time is before release time or not revoked"
        );

        uint256 amount = _token.balanceOf(address(this));
        require(amount > 0, "TokenTimelock: no tokens to release");

        _token.safeTransfer(msg.sender, amount);
        emit TokenReleased(_token, amount);
    }

    /**
     * @notice Add an address that is eligible to unlock tokens.
     */
    function addBeneficiary(address newBeneficiary) external onlyBeneficiary {
        addBeneficiaryInternal(newBeneficiary);
    }

    /**
     * @notice Add an address that is eligible to unlock tokens.
     */
    function addBeneficiaryInternal(address newBeneficiary) internal {
        beneficiaries.add(newBeneficiary);
        emit BeneficiaryAdded(newBeneficiary);
    }

    /**
     * @notice Allows the owner to revoke the timelock. Tokens already vested
     * @param _token ERC20 token which is being locked
     */
    function revoke(address _token) external onlyAdmin {
        require(revocable, "Contract not revokable");
        require(!revoked[_token], "Already revoked");

        revoked[_token] = true;

        emit Revoked(_token);
    }
}
