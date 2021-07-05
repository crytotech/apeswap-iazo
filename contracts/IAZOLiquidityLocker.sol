//SPDX-License-Identifier: UNLICENSED
//ALL RIGHTS RESERVED
//apeswap.finance

// TODO: Make upgradeable

/**
    This contract creates the lock on behalf of each IAZO. This contract will be whitelisted to bypass the flat rate 
    ETH fee. Please do not use the below locking code in your own contracts as the lock will fail without the ETH fee
*/
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

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IAZOExposer.sol";
import "./IAZOTokenTimelock.sol";
import "./interface/ERC20.sol";

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

// FIXME: Can't be ownable if deployed by another contract
// TODO: Store contracts deployed from this contract
contract IAZOLiquidityLocker is Ownable {
    using SafeERC20 for IERC20;

    IAZOExposer public IAZO_EXPOSER;
    IApeFactory public APE_FACTORY;
    
    constructor(address iazoExposer, address apeFactory) {
        IAZO_EXPOSER = IAZOExposer(iazoExposer);
        APE_FACTORY = IApeFactory(apeFactory);
    }

    // TODO: Rename anything that references PRESALE
    /**
        Send in _token0 as the PRESALE token, _token1 as the BASE token (usually WETH) for the check to work. As anyone can create a pair,
        and send WETH to it while a presale is running, but no one should have access to the presale token. If they do and they send it to 
        the pair, scewing the initial liquidity, this function will return true
    */
    function apePairIsInitialised(address _token0, address _token1) public view returns (bool) {
        address pairAddress = APE_FACTORY.getPair(_token0, _token1);
        if (pairAddress == address(0)) {
            return false;
        }
        uint256 balance = ERC20(_token0).balanceOf(pairAddress);
        if (balance > 0) {
            return true;
        }
        return false;
    }
    
    function lockLiquidity(
        ERC20 _baseToken, 
        ERC20 _saleToken, 
        uint256 _baseAmount, 
        uint256 _saleAmount, 
        uint256 _unlock_date, 
        address payable _withdrawer, 
        address _admin
    ) external returns (address) {
        require(IAZO_EXPOSER.IAZOIsRegistered(msg.sender), 'IAZO NOT REGISTERED');
        address pairAddress = APE_FACTORY.getPair(address(_baseToken), address(_saleToken));
        IERC20 pair = IERC20(pairAddress);
        if (pairAddress == address(0)) {
            APE_FACTORY.createPair(address(_baseToken), address(_saleToken));
            pairAddress = APE_FACTORY.getPair(address(_baseToken), address(_saleToken));
        }
        
        _baseToken.transferFrom(msg.sender, pairAddress, _baseAmount);
        _saleToken.transferFrom(msg.sender, pairAddress, _saleAmount);

        IApePair(pairAddress).mint(address(this));
        uint256 totalLPTokensMinted = IApePair(pairAddress).balanceOf(address(this));
        require(totalLPTokensMinted != 0 , "LP creation failed");

        uint256 unlock_date = _unlock_date > 9999999999 ? 9999999999 : _unlock_date;
        // Maybe use a separate factory so that it can be easily upgraded and used for other purposes?
        // TODO: Instead of passing an admin address we can pass the settings contract so that it can reference a dynamic admin
        IAZOTokenTimelock tokenTimelock = new IAZOTokenTimelock(_admin, _withdrawer, unlock_date, true);
        // TODO: Log the location of the lock
        // TODO: Will tokens get locked in this contract if these fail?
        require(tokenTimelock.isTokenTimelock(), 'new TokenTimelock has failed');
        // TODO: Use a deposit function instead to verify that it was transferred in?
        pair.safeTransfer(address(tokenTimelock), totalLPTokensMinted);
        // TODO: emit
        return address(pair);


        // FIXME: Will remove with vesting contract
        // pair.approve(address(UNISWAP_LOCKER), totalLPTokensMinted);
        // uint256 unlock_date = _unlock_date > 9999999999 ? 9999999999 : _unlock_date;
        // UNISWAP_LOCKER.lockLPToken(pairAddress, totalLPTokensMinted, unlock_date, payable(0), true, _withdrawer);
    }
    
}