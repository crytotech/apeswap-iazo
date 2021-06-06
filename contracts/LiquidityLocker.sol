//SPDX-License-Identifier: UNLICENSED
//ALL RIGHTS RESERVED
//apeswap.finance

/**
    This contract creates the lock on behalf of each ILO. This contract will be whitelisted to bypass the flat rate 
    ETH fee. Please do not use the below locking code in your own contracts as the lock will fail without the ETH fee
*/

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/ERC20.sol";

interface IPresaleFactory {
    function registerPresale (address _presaleAddress) external;
    function presaleIsRegistered(address _presaleAddress) external view returns (bool);
}

interface IUniswapV2Locker {
    function lockLPToken (address _lpToken, uint256 _amount, uint256 _unlock_date, address payable _referral, bool _fee_in_eth, address payable _withdrawer) external payable;
}

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Pair {
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

contract LiquidityLocker is Ownable {
    
    IPresaleFactory public PRESALE_FACTORY;
    IUniswapV2Locker public UNISWAP_LOCKER;
    IUniswapV2Factory public UNI_FACTORY;
    
    constructor() {
        PRESALE_FACTORY = IPresaleFactory(0x206EC1d1C0147f5B2b8D302901Bfb6b7CBFAcb09);
        UNISWAP_LOCKER = IUniswapV2Locker(0xC765bddB93b0D1c1A88282BA0fa6B2d00E3e0c83);
        UNI_FACTORY = IUniswapV2Factory(0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73);
    }

    /**
        Send in _token0 as the PRESALE token, _token1 as the BASE token (usually WETH) for the check to work. As anyone can create a pair,
        and send WETH to it while a presale is running, but no one should have access to the presale token. If they do and they send it to 
        the pair, scewing the initial liquidity, this function will return true
    */
    function uniswapPairIsInitialised (address _token0, address _token1) public view returns (bool) {
        address pairAddress = UNI_FACTORY.getPair(_token0, _token1);
        if (pairAddress == address(0)) {
            return false;
        }
        uint256 balance = ERC20(_token0).balanceOf(pairAddress);
        if (balance > 0) {
            return true;
        }
        return false;
    }
    
    function lockLiquidity (ERC20 _baseToken, ERC20 _saleToken, uint256 _baseAmount, uint256 _saleAmount, uint256 _unlock_date, address payable _withdrawer) external {
        require(PRESALE_FACTORY.presaleIsRegistered(msg.sender), 'PRESALE NOT REGISTERED');
        address pairAddress = UNI_FACTORY.getPair(address(_baseToken), address(_saleToken));
        ERC20 pair = ERC20(pairAddress);
        if (pairAddress == address(0)) {
            UNI_FACTORY.createPair(address(_baseToken), address(_saleToken));
            pairAddress = UNI_FACTORY.getPair(address(_baseToken), address(_saleToken));
        }
        
        _baseToken.transferFrom(msg.sender, pairAddress, _baseAmount);
        _saleToken.transferFrom(msg.sender, pairAddress, _saleAmount);

        IUniswapV2Pair(pairAddress).mint(address(this));
        uint256 totalLPTokensMinted = IUniswapV2Pair(pairAddress).balanceOf(address(this));
        require(totalLPTokensMinted != 0 , "LP creation failed");
    
        pair.approve(address(UNISWAP_LOCKER), totalLPTokensMinted);
        uint256 unlock_date = _unlock_date > 9999999999 ? 9999999999 : _unlock_date;
        UNISWAP_LOCKER.lockLPToken(pairAddress, totalLPTokensMinted, unlock_date, payable(0), true, _withdrawer);
    }
    
}