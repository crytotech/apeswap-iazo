//SPDX-License-Identifier: UNLICENSED
//ALL RIGHTS RESERVED
//apeswap.finance

// FIXME: Review defiyield audit to avoid low risk bugs
// TODO: Add sweep token functionality to unlock messed up IAZOs?
// TODO: Make upgradeable

pragma solidity 0.8.4;

/*
 * ApeSwapFinance 
 * App:             https://apeswap.finance
 * Medium:          https://ape-swap.medium.com    
 * Twitter:         https://twitter.com/ape_swap 
 * Telegram:        https://t.me/ape_swap
 * Announcements:   https://t.me/ape_swap_news
 * GitHub:          https://github.com/ApeSwapFinance
 */

import "./interface/ERC20.sol";
import "./interface/IIAZOSettings.sol";
import "./IAZO.sol";

interface IIAZO_EXPOSER {
    function initializeExposer(address iazoFactory) external;
    function registerIAZO(address newIAZO) external;
}

contract IAZOFactory {
    IIAZO_EXPOSER public IAZO_EXPOSER;
    IIAZOSettings public IAZO_SETTINGS;
    IIAZOLiquidityLocker public IAZO_LIQUIDITY_LOCKER;
    IWNative public WNATIVE;

    bool public isIAZOFactory = true;

    event IAZOCreated(address indexed newIAZO);

    struct IAZOParams {
        uint256 TOKEN_PRICE; // cost for 1 IAZO_TOKEN in BASE_TOKEN (or NATIVE)
        uint256 AMOUNT; // AMOUNT of IAZO_TOKENS for sale
        uint256 HARDCAP; // HARDCAP of earnings.
        uint256 SOFTCAP; // SOFTCAP for earning. if not reached IAZO is cancelled
        uint256 START_BLOCK; // block to start IAZO
        uint256 ACTIVE_BLOCKS; // end of IAZO -> START_BLOCK + ACTIVE_BLOCKS
        uint256 LOCK_PERIOD; // days to lock earned tokens for IAZO_OWNER
        uint256 MAX_SPEND_PER_BUYER; // max spend per buyer
        uint256 LIQUIDITY_PERCENT; // Percentage of coins that will be locked in liquidity
        uint256 LISTING_PRICE; // fixed rate at which the token will list on apeswap
    }

    constructor(IIAZO_EXPOSER iazoExposer, IIAZOSettings iazoSettings, IIAZOLiquidityLocker iazoliquidityLocker, IWNative wnative) {
        IAZO_EXPOSER = iazoExposer;
        IAZO_EXPOSER.initializeExposer(address(this));
        IAZO_SETTINGS = iazoSettings;
        require(IAZO_SETTINGS.isIAZOSettings(), 'isIAZOSettings call returns false');
        IAZO_LIQUIDITY_LOCKER = iazoliquidityLocker;
        require(IAZO_LIQUIDITY_LOCKER.isIAZOLiquidityLocker(), 'isIAZOLiquidityLocker call returns false');
        WNATIVE = wnative;
    }

    // Create new IAZO and add address to IAZOExposer.
    function createIAZO(
        address payable _IAZOOwner,
        ERC20 _IAZOToken,
        ERC20 _baseToken,
        bool _prepaidFee,
        bool _burnRemains,
        uint256[9] memory uint_params
    ) public payable {
        require(address(_baseToken) != address(0), "Base token cannot be address(0)");
        IAZOParams memory params;
        params.TOKEN_PRICE = uint_params[0];
        params.AMOUNT = uint_params[1];
        params.SOFTCAP = uint_params[2];
        params.START_BLOCK = uint_params[3];
        params.ACTIVE_BLOCKS = uint_params[4];
        params.LOCK_PERIOD = uint_params[5];
        params.MAX_SPEND_PER_BUYER = uint_params[6];
        params.LIQUIDITY_PERCENT = uint_params[7];
        if(uint_params[8] == 0){
            params.LISTING_PRICE = params.TOKEN_PRICE;
        } else {
            params.LISTING_PRICE = uint_params[8];
        }

        // Check that the unlock time was not sent in ms
        // This timestamp is Nov 20 2286
        require(params.LOCK_PERIOD < 9999999999, 'unlock time is too large ');
        // Lock period must be greater than the min lock period
        require(params.LOCK_PERIOD >= IAZO_SETTINGS.getMinLockPeriod(), 'Lock period too low');

        // Charge ETH fee for contract creation
        if(_prepaidFee){
            require(
                msg.value >= IAZO_SETTINGS.getEthCreationFee(),
                "Fee not met"
            );
            /// @notice the entire funds sent in the tx will be taken as long as it's above the ethCreationFee
            IAZO_SETTINGS.getFeeAddress().transfer(
                address(this).balance
            );
        }

        require(params.START_BLOCK > block.number, "iazo should start in future");
        require(
            params.ACTIVE_BLOCKS >= IAZO_SETTINGS.getMinIAZOLength(), 
            "iazo length not long enough"
        );
        require(
            params.ACTIVE_BLOCKS <= IAZO_SETTINGS.getMaxIAZOLength(), 
            "Exceeds max iazo length"
        );

        /// @notice require(params.AMOUNT > tokenDecimals) was removed below in place of this check
        require(params.AMOUNT >= 10000, "Minimum divisibility");
        require(params.TOKEN_PRICE > 0, "Invalid token price");
        /// @dev Adjust liquidity percentage settings here
        require(
            params.LIQUIDITY_PERCENT >= 30 && params.LIQUIDITY_PERCENT <= 100,
            "Liquidity percentage too low"
        ); // 30% minimum liquidity lock

        uint256 tokenDecimals = _IAZOToken.decimals();
        uint256 hardcap = params.AMOUNT * params.TOKEN_PRICE / (10 ** tokenDecimals);
        // Check that the hardcap is greater than or equal to softcap
        require(hardcap >= params.SOFTCAP, 'softcap is greater than hardcap');

        uint256 tokensRequired = getTokensRequired(
            params.AMOUNT,
            params.TOKEN_PRICE,
            params.LISTING_PRICE, 
            params.LIQUIDITY_PERCENT,
            hardcap,
            tokenDecimals
        );

        // Deploy a new IAZO contract
        IAZO newIAZO = new IAZO(address(IAZO_SETTINGS), address(IAZO_LIQUIDITY_LOCKER), WNATIVE);
        
        newIAZO.initializeIAZO(
            _IAZOOwner,
            _IAZOToken,
            _baseToken,
            params.TOKEN_PRICE,
            params.AMOUNT,
            hardcap,
            params.SOFTCAP,
            params.MAX_SPEND_PER_BUYER,
            params.LIQUIDITY_PERCENT,
            params.LISTING_PRICE
        );

        newIAZO.initializeIAZO2(
            params.START_BLOCK,
            params.ACTIVE_BLOCKS,
            params.LOCK_PERIOD,
            _prepaidFee,
            _burnRemains,
            IAZO_SETTINGS.getFeeAddress(),
            IAZO_SETTINGS.getBaseFee()
        );

        IAZO_EXPOSER.registerIAZO(address(newIAZO));

        // NOTE: Moved this to the bottom so tokens don't get locked here
        _IAZOToken.transferFrom(address(msg.sender), address(newIAZO), tokensRequired);

        emit IAZOCreated(address(newIAZO));
    }

    // FIXME: _tokenPrice
    function getTokensRequired (uint256 _amount, uint256 _tokenPrice, uint256 _listingPrice, uint256 _liquidityPercent, uint256 _hardcap, uint256 _decimals) internal pure returns (uint256) {
        // uint256 listingRatePercent = _listingRate * 1000 / _tokenPrice;
        // uint256 fee = _amount * _tokenFee / 1000;
        // uint256 amountMinusFee = _amount - fee;
        // uint256 liquidityRequired = amountMinusFee * _liquidityPercent * listingRatePercent / 1000000;
        // uint256 tokensRequiredForPresale = _amount + liquidityRequired + fee;
        // return tokensRequiredForPresale;

        uint256 liquidityRequired = _hardcap * _liquidityPercent * (10 ** _decimals) / 100 / _listingPrice;
        require(liquidityRequired > 0, "Something wrong with liquidity values");
        uint256 tokensRequired = _amount + liquidityRequired;
        return tokensRequired;
    }
}
