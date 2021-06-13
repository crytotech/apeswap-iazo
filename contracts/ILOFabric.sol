//SPDX-License-Identifier: UNLICENSED
//ALL RIGHTS RESERVED
//apeswap.finance

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/ERC20.sol";
import "./ILOSettings.sol";
import "./ILOExposer.sol";
import "./ILO.sol";

contract ILOFabric is Ownable {
    ILOExposer public ILO_EXPOSER;
    ILOSettings public ILO_SETTINGS;

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

    constructor() {
        ILO_EXPOSER = new ILOExposer(address(this));
        ILO_SETTINGS = ILOSettings(
            0xE4475182c2dA3d7C37f9174322F34B67fabCD975
        );
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

        if (params.LOCK_PERIOD < ILO_SETTINGS.getMinLockPeriod()) {
            params.LOCK_PERIOD = ILO_SETTINGS.getMinLockPeriod();
        }

        // Charge ETH fee for contract creation
        if(_prepaidFee){
            require(
                msg.value >= ILO_SETTINGS.getEthCreationFee(),
                "Fee not met"
            );
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

        require(params.AMOUNT >= 10000, "Minimum divisibility");
        require(params.TOKEN_PRICE > 0, "Invalid token price");
        require(
            params.LIQUIDITY_PERCENT >= 30 && params.LIQUIDITY_PERCENT <= 100,
            "Liquidity percentage too low"
        ); // 30% minimum liquidity lock

        uint256 tokenDecimals = _ILOToken.decimals();
        require(params.AMOUNT > tokenDecimals);
        uint256 hardcap = params.AMOUNT * params.TOKEN_PRICE / (10 ** tokenDecimals);


        uint256 tokensRequired = getTokensRequired(
            params.AMOUNT,
            params.TOKEN_PRICE,
            params.LISTING_PRICE, 
            params.LIQUIDITY_PERCENT,
            hardcap,
            tokenDecimals
        );

        ILO newILO = new ILO(address(this));
        
        _ILOToken.transferFrom(address(msg.sender), address(newILO), tokensRequired);

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
            ILO_SETTINGS.getBaseFee(),
            ILO_SETTINGS.getAdminAddress()
        );

        ILO_EXPOSER.registerILO(address(newILO));
    }

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
