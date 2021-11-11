//SPDX-License-Identifier: UNLICENSED
//ALL RIGHTS RESERVED
//apeswap.finance

/**
    This contract creates the lock on behalf of each IAZO. This contract will be whitelisted to bypass the flat rate 
    ETH fee. Please do not use the below locking code in your own contracts as the lock will fail without the ETH fee
*/
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

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./IAZOExposer.sol";
import "./interface/IIAZOTokenTimelock.sol";
import "./interface/IIAZOSettings.sol";

interface IApeFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IApePair {
    function balanceOf(address owner) external view returns (uint);
    function approve(address spender, uint value) external returns (bool);
    function mint(address to) external returns (uint liquidity);
}

/// @title IAZO Liquidity Locker
/// @author ApeSwapFinance
/// @notice Locks liquidity on successful IAZO
contract IAZOLiquidityLocker is OwnableUpgradeable {
    using SafeERC20 for IERC20;

    IAZOExposer public IAZO_EXPOSER;
    IApeFactory public APE_FACTORY;
    IIAZOSettings public IAZO_SETTINGS;
    IIAZOTokenTimelock tokenTimelockImplementation;

    // Flag to determine contract type 
    bool constant public isIAZOLiquidityLocker = true;

    event IAZOLiquidityLocked(
        address indexed iazo, 
        IIAZOTokenTimelock indexed iazoTokenlockContract, 
        address indexed pairAddress, 
        uint256 totalLPTokensMinted
    );
    event SweepWithdraw(
        address indexed receiver, 
        IERC20 indexed token, 
        uint256 balance
    );

    function initialize (
        address iazoExposer, 
        address apeFactory, 
        address iazoSettings, 
        address admin, 
        address initialTokenTimelockImplementation
    ) external initializer {
        // Set admin as owner
        __Ownable_init();
        transferOwnership(admin);

        IAZO_EXPOSER = IAZOExposer(iazoExposer);
        APE_FACTORY = IApeFactory(apeFactory);
        IAZO_SETTINGS = IIAZOSettings(iazoSettings);
        require(IIAZOTokenTimelock(initialTokenTimelockImplementation).isIAZOTokenTimelock(), 'token timelock implementation');
        tokenTimelockImplementation = IIAZOTokenTimelock(initialTokenTimelockImplementation);
    }

    /**
        As anyone can create a pair, and send WETH to it while a IAZO is running, but no one should have access to the IAZO token. If they do and they send it to 
        the pair, screwing the initial liquidity, this function will return true
    */
    /// @notice Check if the token pair is initialized or not
    /// @param _iazoToken The address of the IAZO token
    /// @param _baseToken The address of the base token
    /// @return Whether the token pair is initialized or not
    function apePairIsInitialized(address _iazoToken, address _baseToken) external view returns (bool) {
        address pairAddress = APE_FACTORY.getPair(_iazoToken, _baseToken);
        if (pairAddress == address(0)) {
            return false;
        }
        uint256 balance = IERC20(_iazoToken).balanceOf(pairAddress);
        if (balance > 0) {
            return true;
        }
        return false;
    }
    
    /// @notice Lock the liquidity of sale and base tokens
    /// @dev The IIAZOTokenTimelock can have tokens revoked to be released early by the admin. This is a 
    ///  safety mechanism in case the wrong tokens are sent to the contract.
    /// @param _baseToken The address of the base token
    /// @param _saleToken The address of the IAZO token
    /// @param _baseAmount The amount of base tokens to lock as liquidity
    /// @param _saleAmount The amount of IAZO tokens to lock as liquidity
    /// @param _unlockDate The date where the liquidity can be unlocked
    /// @param _withdrawer The address which can withdraw the liquidity after unlocked
    /// @return The address of liquidity pair
    function lockLiquidity(
        IERC20 _baseToken, 
        IERC20 _saleToken, 
        uint256 _baseAmount, 
        uint256 _saleAmount, 
        uint256 _unlockDate, 
        address payable _withdrawer
    ) external returns (address) {
        // Must be from a registered IAZO contract
        require(IAZO_EXPOSER.IAZOIsRegistered(msg.sender), 'IAZO NOT REGISTERED');
        // get/setup pair
        address pairAddress = APE_FACTORY.getPair(address(_baseToken), address(_saleToken));
        if (pairAddress == address(0)) {
            pairAddress = APE_FACTORY.createPair(address(_baseToken), address(_saleToken));
        }
        IApePair pair = IApePair(pairAddress);

        // Transfer tokens from IAZO contract to pair
        _baseToken.safeTransferFrom(msg.sender, pairAddress, _baseAmount);
        _saleToken.safeTransferFrom(msg.sender, pairAddress, _saleAmount);
        // Mint lp tokens
        pair.mint(address(this));
        uint256 totalLPTokensMinted = pair.balanceOf(address(this));
        require(totalLPTokensMinted != 0 , "LP creation failed");

        // Setup token timelock
        IIAZOTokenTimelock iazoTokenTimelock = IIAZOTokenTimelock(Clones.clone(address(tokenTimelockImplementation)));
        iazoTokenTimelock.initialize(IAZO_SETTINGS, _withdrawer, _unlockDate);
        require(iazoTokenTimelock.isIAZOTokenTimelock(), 'token timelock did not deploy correctly');
        require(iazoTokenTimelock.isBeneficiary(_withdrawer), 'improper beneficiary set');
        // Transfer lp tokens into token timelock
        pair.approve(address(iazoTokenTimelock), totalLPTokensMinted);
        iazoTokenTimelock.deposit(IERC20(address(pair)), totalLPTokensMinted);
        // Add token timelock to exposer
        IAZO_EXPOSER.addTokenTimelock(msg.sender, address(iazoTokenTimelock));
        emit IAZOLiquidityLocked(msg.sender, iazoTokenTimelock, pairAddress, totalLPTokensMinted);

        return address(pair);
    }

    /// @notice A public function to sweep accidental ERC20 transfers to this contract. 
    /// @param _tokens Array of ERC20 addresses to sweep
    /// @param _to Address to send tokens to
    function sweepTokens(IERC20[] memory _tokens, address _to) external onlyOwner {
        for (uint256 index = 0; index < _tokens.length; index++) {
            IERC20 token = _tokens[index];
            uint256 balance = token.balanceOf(address(this));
            token.safeTransfer(_to, balance);
            emit SweepWithdraw(_to, token, balance);
        }
    }
}