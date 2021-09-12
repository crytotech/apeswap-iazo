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

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "./OwnableProxy.sol";
import "./IAZOExposer.sol";
import "./IAZOTokenTimelock.sol";
import "./interface/IIAZOSettings.sol";

interface IApeFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IApePair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

/// @title IAZO Liquidity Locker
/// @author ApeSwapFinance
/// @notice Locks liquidity on succesful IAZO
contract IAZOLiquidityLocker is OwnableProxy, Initializable {
    using SafeERC20 for IERC20;

    IAZOExposer public IAZO_EXPOSER;
    IApeFactory public APE_FACTORY;
    IIAZOSettings public IAZO_SETTINGS;

    // Flag to determine contract type 
    bool constant public isIAZOLiquidityLocker = true;

    event IAZOLiquidityLocked(
        address indexed iazo, 
        IAZOTokenTimelock indexed iazoTokenlockContract, 
        address indexed pairAddress, 
        uint256 totalLPTokensMinted
    );
    event SweepWithdraw(
        address indexed receiver, 
        IERC20 indexed token, 
        uint256 balance
    );

    function initialize (address iazoExposer, address apeFactory, address iazoSettings, address admin) external initializer {
        _owner = admin;

        IAZO_EXPOSER = IAZOExposer(iazoExposer);
        APE_FACTORY = IApeFactory(apeFactory);
        IAZO_SETTINGS = IIAZOSettings(iazoSettings);
    }

    /**
        As anyone can create a pair, and send WETH to it while a IAZO is running, but no one should have access to the IAZO token. If they do and they send it to 
        the pair, scewing the initial liquidity, this function will return true
    */
    /// @notice Check if the token pair is initialised or not
    /// @param _iazoToken The address of the IAZO token
    /// @param _baseToken The address of the base token
    /// @return Whether the token pair is initialised or not
    function apePairIsInitialised(address _iazoToken, address _baseToken) external view returns (bool) {
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
    /// @param _baseToken The address of the base token
    /// @param _saleToken The address of the IAZO token
    /// @param _baseAmount The amount of base tokens to lock as liquidity
    /// @param _saleAmount The amount of IAZO tokens to lock as liquidity
    /// @param _unlock_date The date where the liquidity can be unlocked
    /// @param _withdrawer The address which can withdraw the liquidity after unlocked
    /// @param _iazoAddress The address of the IAZO
    /// @return The address of liquidity pair
    function lockLiquidity(
        IERC20 _baseToken, 
        IERC20 _saleToken, 
        uint256 _baseAmount, 
        uint256 _saleAmount, 
        uint256 _unlock_date, 
        address payable _withdrawer,
        address _iazoAddress
    ) external returns (address) {
        // Must be from a registered IAZO contract
        require(IAZO_EXPOSER.IAZOIsRegistered(msg.sender), 'IAZO NOT REGISTERED');
        // get/setup pair
        address pairAddress = APE_FACTORY.getPair(address(_baseToken), address(_saleToken));
        if (pairAddress == address(0)) {
            APE_FACTORY.createPair(address(_baseToken), address(_saleToken));
            pairAddress = APE_FACTORY.getPair(address(_baseToken), address(_saleToken));
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
        IAZOTokenTimelock iazoTokenTimelock = new IAZOTokenTimelock(IAZO_SETTINGS, _withdrawer, _unlock_date, true);
        require(iazoTokenTimelock.isIAZOTokenTimelock(), 'token timelock did not deploy correctly');
        require(iazoTokenTimelock.isBeneficiary(_withdrawer), 'improper beneficiary set');
        // Transfer lp tokens into token timelock
        pair.approve(address(iazoTokenTimelock), totalLPTokensMinted);
        iazoTokenTimelock.deposit(IERC20(address(pair)), totalLPTokensMinted);
        // Add token timelock to exposer
        IAZO_EXPOSER.addTokenTimelock(_iazoAddress, address(iazoTokenTimelock));
        emit IAZOLiquidityLocked(msg.sender, iazoTokenTimelock, pairAddress, totalLPTokensMinted);

        return address(pair);
    }

    /// @notice A public function to sweep accidental ERC20 transfers to this contract. 
    ///   Tokens are sent to owner
    /// @param token The address of the ERC20 token to sweep
    function sweepToken(IERC20 token) external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        token.safeTransfer(msg.sender, balance);
        emit SweepWithdraw(msg.sender, token, balance);
    }
}