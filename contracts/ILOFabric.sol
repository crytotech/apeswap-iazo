//SPDX-License-Identifier: UNLICENSED
//ALL RIGHTS RESERVED
//apeswap.finance

// FIXME: Review defiyield audit to avoid low risk bugs
// TODO: Add in media links
// TODO: Add sweep token functionality to unlock messed up ILOs?
// TODO: Make upgradeable

pragma solidity ^0.8.4;

import "./interface/ERC20.sol";
import "./interface/IILOSettings.sol";
import "./ILO.sol";

interface ILiquidityLocker {
    function isLiquidityLocker() external returns (bool);
}

interface IILO_EXPOSER {
    function initializeExposer(address iloFabric) external;
    function registerILO(address newILO) external;
}

// TODO: Contract exceed recommended size. Need to make it smaller
contract ILOFabric {
    IILO_EXPOSER public ILO_EXPOSER;
    IILOSettings public ILO_SETTINGS; // TODO: function to update settings contract?
    ILiquidityLocker public LIQUIDITY_LOCKER; // TODO: function to update liquidity locker contract?
    address public WBNB;

    bool public isILOFabric = true;

    struct ILOParams {
        uint256 TOKEN_PRICE; // cost for 1 ILO_TOKEN in BASE_TOKEN (or BNB)
        uint256 AMOUNT; // AMOUNT of ILO_TOKENS for sale
        uint256 HARDCAP; // HARDCAP of earnings.
        uint256 SOFTCAP; // SOFTCAP for earning. if not reached ILO is cancelled
        uint256 START_BLOCK; // block to start ILO
        uint256 ACTIVE_BLOCKS; // end of ILO -> START_BLOCK + ACTIVE_BLOCKS
        uint256 LOCK_PERIOD; // days to lock earned tokens for ILO_OWNER
        uint256 MAX_SPEND_PER_BUYER; // max spend per buyer
        uint256 LIQUIDITY_PERCENT; // Percentage of coins that will be locked in liquidity
        uint256 LISTING_PRICE; // fixed rate at which the token will list on apeswap
    }

    constructor(address iloExposer, IILOSettings iloSettings, ILiquidityLocker liquidityLocker, address wbnb) {
        ILO_EXPOSER = IILO_EXPOSER(iloExposer);
        ILO_EXPOSER.initializeExposer(address(this));
        ILO_SETTINGS = iloSettings;
        require(ILO_SETTINGS.isILOSettings(), 'isILOSettings call returns false');
        LIQUIDITY_LOCKER = liquidityLocker;
        require(LIQUIDITY_LOCKER.isLiquidityLocker(), 'isLiquidityLocker call returns false');
        // TODO: verify wbnb?
        WBNB = wbnb;
    }

    // Create new ILO and add address to ILOExposer.
    function createILO(
        address payable _ILOOwner,
        ERC20 _ILOToken,
        ERC20 _baseToken,
        bool _prepaidFee,
        bool _burnRemains,
        uint256[9] memory uint_params
    ) public payable {
        ILOParams memory params;
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
        // If lock period is less than min period then set it to the min period
        if (params.LOCK_PERIOD < ILO_SETTINGS.getMinLockPeriod()) {
            params.LOCK_PERIOD = ILO_SETTINGS.getMinLockPeriod();
        }

        // Charge ETH fee for contract creation
        if(_prepaidFee){
            require(
                msg.value >= ILO_SETTINGS.getEthCreationFee(),
                "Fee not met"
            );
            // TODO: This transfers the entire balance of the creation and not only the fee 
            ILO_SETTINGS.getFeeAddress().transfer(
                address(this).balance
            );
        }

        require(params.START_BLOCK > block.number, "ilo should start in future");
        require(
            params.ACTIVE_BLOCKS >= ILO_SETTINGS.getMinILOLength(), 
            "ilo length not long enough"
        );
        require(
            params.ACTIVE_BLOCKS <= ILO_SETTINGS.getMaxILOLength(), 
            "Exceeds max ilo length"
        );

        // TODO: add this value to settings?
        require(params.AMOUNT >= 10000, "Minimum divisibility");
        require(params.TOKEN_PRICE > 0, "Invalid token price");
        // TODO: add this value to settings?
        require(
            params.LIQUIDITY_PERCENT >= 30 && params.LIQUIDITY_PERCENT <= 100,
            "Liquidity percentage too low"
        ); // 30% minimum liquidity lock

        uint256 tokenDecimals = _ILOToken.decimals();
        // FIXME: removing as tokenDecimals will never be over 18 and we already check above for greater than 1000
        // require(params.AMOUNT > tokenDecimals);
        uint256 hardcap = params.AMOUNT * params.TOKEN_PRICE / (10 ** tokenDecimals);

        // TODO: require hardcap is greater than soft cap?

        // NOTE: left here
        uint256 tokensRequired = getTokensRequired(
            params.AMOUNT,
            params.TOKEN_PRICE,
            params.LISTING_PRICE, 
            params.LIQUIDITY_PERCENT,
            hardcap,
            tokenDecimals
        );

        // Deploy a new ILO contract
        ILO newILO = new ILO(address(ILO_SETTINGS), address(LIQUIDITY_LOCKER), address(WBNB));
        
        newILO.initializeILO(
            _ILOOwner,
            _ILOToken,
            _baseToken,
            params.TOKEN_PRICE,
            params.AMOUNT,
            hardcap,
            params.SOFTCAP,
            params.MAX_SPEND_PER_BUYER,
            params.LIQUIDITY_PERCENT,
            params.LISTING_PRICE
        );

        newILO.initializeILO2(
            params.START_BLOCK,
            params.ACTIVE_BLOCKS,
            params.LOCK_PERIOD,
            _prepaidFee,
            _burnRemains,
            ILO_SETTINGS.getFeeAddress(),
            ILO_SETTINGS.getBaseFee()
        );

        ILO_EXPOSER.registerILO(address(newILO));

        // NOTE: Moved this to the bottom so tokens don't get locked here
        _ILOToken.transferFrom(address(msg.sender), address(newILO), tokensRequired);

        // TODO: emit Event
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
