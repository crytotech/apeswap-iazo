//SPDX-License-Identifier: UNLICENSED
//ALL RIGHTS RESERVED
//apeswap.finance

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
import "./interface/ERC20.sol";
import "./interface/IIAZOSettings.sol";
import "./interface/IIAZOLiquidityLocker.sol";
import "./interface/IWNative.sol";


interface IIAZO_EXPOSER {
    function initializeExposer(address _iazoFactory, address _liquidityLocker) external;
    function registerIAZO(address newIAZO) external;
}

interface IIAZO {
    function isIAZO() external returns (bool);

    function initialize(
        // _addresses = [IAZOSettings, IAZOLiquidityLocker]
        address[2] memory _addresses, 
        // _addressesPayable = [IAZOOwner, feeAddress]
        address payable[2] memory _addressesPayable, 
        // _uint256s = [_tokenPrice,  _amount, _hardcap,  _softcap, _maxSpendPerBuyer, _liquidityPercent, _listingPrice, _startBlock, _activeBlocks, _lockPeriod, _baseFee, _iazoTokenFee]
        uint256[12] memory _uint256s, 
        // _bools = [_burnRemains]
        bool[1] memory _bools, 
        // _ERC20s = [_iazoToken, _baseToken]
        ERC20[2] memory _ERC20s, 
        IWNative _wnative
    ) external;     
}

/// @title IAZO factory 
/// @author ApeSwapFinance
/// @notice Factory to create new IAZOs
/// @dev This contract currently does NOT support non-standard ERC-20 tokens with fees on transfers
contract IAZOFactory is OwnableUpgradeable {
    IIAZO_EXPOSER public IAZO_EXPOSER;
    IIAZOSettings public IAZO_SETTINGS;
    IIAZOLiquidityLocker public IAZO_LIQUIDITY_LOCKER;
    IWNative public WNative;

    IIAZO[] public IAZOImplementations;
    uint256 public IAZOVersion;

    bool constant public isIAZOFactory = true;

    event IAZOCreated(address indexed newIAZO);
    event PushIAZOVersion(IIAZO indexed newIAZO, uint256 versionId);
    event UpdateIAZOVersion(uint256 previousVersion, uint256 newVersion);
    event SweepWithdraw(
        address indexed receiver, 
        IERC20 indexed token, 
        uint256 balance
    );

    struct IAZOParams {
        /// @dev To account for tokens with different decimals values the TOKEN_PRICE/LISTING_PRICE need to account for that
        /// Find the amount of tokens in BASE_TOKENS that 1 IAZO_TOKEN costs and use the equation below to find the TOKEN_PRICE
        /// TOKEN_PRICE = BASE_TOKEN_AMOUNT * 10**(18 - iazoTokenDecimals)
        /// i.e. 1 IAZO 8 decimal token (1e8) = 1 BASE_TOKEN 18 decimal token (1e18): TOKEN_PRICE = 1e28
        uint256 TOKEN_PRICE; // BASE_TOKEN_AMOUNT * 10**(18 - iazoTokenDecimals)
        uint256 AMOUNT; // AMOUNT of IAZO_TOKENS for sale
        uint256 HARDCAP; // HARDCAP of earnings.
        uint256 SOFTCAP; // SOFTCAP for earning. if not reached IAZO is cancelled
        uint256 START_TIME; // start timestamp of the IAZO
        uint256 ACTIVE_TIME; // end of IAZO -> START_TIME + ACTIVE_TIME
        uint256 LOCK_PERIOD; // days to lock earned tokens for IAZO_OWNER
        uint256 MAX_SPEND_PER_BUYER; // max spend per buyer
        uint256 LIQUIDITY_PERCENT; // Percentage of coins that will be locked in liquidity
        /// @dev Find the amount of tokens in BASE_TOKENS that 1 IAZO_TOKEN will be listed for and use the equation below to find the LISTING_PRICE
        /// LISTING_PRICE = BASE_TOKEN_AMOUNT * 10**(18 - iazoTokenDecimals)
        uint256 LISTING_PRICE; // BASE_TOKEN_AMOUNT * 10**(18 - iazoTokenDecimals)
    }

    /// @notice Initialization of factory
    /// @param _iazoExposer The address of the IAZO exposer
    /// @param _iazoSettings The address of the IAZO settings
    /// @param _iazoliquidityLocker The address of the IAZO liquidity locker
    /// @param _iazoInitialImplementation The address of the initial IAZO implementation
    /// @param _wnative The address of the wrapped native coin
    /// @param _admin The admin address
    function initialize(
        IIAZO_EXPOSER _iazoExposer, 
        IIAZOSettings _iazoSettings, 
        IIAZOLiquidityLocker _iazoliquidityLocker, 
        IIAZO _iazoInitialImplementation,
        IWNative _wnative,
        address _admin
    ) external initializer {
        // Set admin as owner
        __Ownable_init();
        transferOwnership(_admin);
        // Setup the initial IAZO code to be used as the implementation
        require(_iazoInitialImplementation.isIAZO(), 'implementation does not appear to be IAZO');
        IAZOImplementations.push(_iazoInitialImplementation);
        // Assign initial implementation as version zero
        IAZOVersion = 0;
        IAZO_EXPOSER = _iazoExposer;
        IAZO_EXPOSER.initializeExposer(address(this), address(_iazoliquidityLocker));
        IAZO_SETTINGS = _iazoSettings;
        require(IAZO_SETTINGS.isIAZOSettings(), 'isIAZOSettings call returns false');
        IAZO_LIQUIDITY_LOCKER = _iazoliquidityLocker;
        require(IAZO_LIQUIDITY_LOCKER.isIAZOLiquidityLocker(), 'isIAZOLiquidityLocker call returns false');
        WNative = _wnative;
    }

    /// @notice Creates new IAZO and adds address to IAZOExposer
    /// @param _IAZOOwner The address of the IAZO owner
    /// @param _IAZOToken The address of the token to be sold
    /// @param _baseToken The address of the base token to be received
    /// @param _burnRemains Option to burn the remaining unsold tokens
    /// @param _uint_params IAZO settings. token price, amount of tokens for sale, softcap, start time, active time, liquidity locking period, maximum spend per buyer, percentage to lock as liquidity, listing price
    function createIAZO(
        address payable _IAZOOwner,
        ERC20 _IAZOToken,
        ERC20 _baseToken,
        bool _burnRemains,
        uint256[9] memory _uint_params
    ) external payable {
        require(_IAZOOwner != address(0), "IAZO Owner cannot be address(0)");
        require(_IAZOToken != _baseToken, "IAZO token and base token are the same");
        require(address(_baseToken) != address(0), "Base token cannot be address(0)");
        IAZOParams memory params;
        params.TOKEN_PRICE = _uint_params[0];
        params.AMOUNT = _uint_params[1];
        params.SOFTCAP = _uint_params[2];
        params.START_TIME = _uint_params[3];
        params.ACTIVE_TIME = _uint_params[4];
        params.LOCK_PERIOD = _uint_params[5];
        params.MAX_SPEND_PER_BUYER = _uint_params[6];
        params.LIQUIDITY_PERCENT = _uint_params[7];
        if(_uint_params[8] == 0){
            params.LISTING_PRICE = params.TOKEN_PRICE;
        } else {
            params.LISTING_PRICE = _uint_params[8];
        }

        // Check that the unlock time was not sent in ms
        // This timestamp is Nov 20 2286
        require(params.LOCK_PERIOD < 9999999999, 'unlock time is too large ');
        // Lock period must be greater than the min lock period
        require(params.LOCK_PERIOD >= IAZO_SETTINGS.getMinLockPeriod(), 'Lock period too low');

        // Charge native coin fee for contract creation
        require(
            msg.value >= IAZO_SETTINGS.getNativeCreationFee(),
            "Fee not met"
        );
        /// @notice the entire funds sent in the tx will be taken as long as it's above the ethCreationFee
        IAZO_SETTINGS.getFeeAddress().transfer(
            address(this).balance
        );

        require(params.START_TIME >= IAZO_SETTINGS.getMinStartTime(), "start delay too short");
        require(
            params.ACTIVE_TIME >= IAZO_SETTINGS.getMinIAZOLength(), 
            "iazo length not long enough"
        );
        require(
            params.ACTIVE_TIME <= IAZO_SETTINGS.getMaxIAZOLength(), 
            "Exceeds max iazo length"
        );

        /// @dev This is a check to ensure the amount is greater than zero, but also there are enough tokens
        ///   to handle percent and liquidity calculations.
        require(params.AMOUNT >= 10000, "amount is less than minimum divisibility");
        // Find the hard cap of the offering in base tokens
        uint256 hardcap = getHardCap(params.AMOUNT, params.TOKEN_PRICE);
        require(hardcap > 0, 'hardcap cannot be zero, please check the token price');
        // Check that the hardcap is greater than or equal to softcap
        require(hardcap >= params.SOFTCAP, 'softcap is greater than hardcap');

        /// @dev Adjust liquidity percentage settings here
        require(
            params.LIQUIDITY_PERCENT >= IAZO_SETTINGS.getMinLiquidityPercent() && params.LIQUIDITY_PERCENT <= 1000,
            "Liquidity percentage too low"
        );

        uint256 IAZOTokenFee = IAZO_SETTINGS.getIAZOTokenFee();

        uint256 tokensRequired = _getTokensRequired(
            params.AMOUNT,
            params.TOKEN_PRICE,
            params.LISTING_PRICE, 
            params.LIQUIDITY_PERCENT,
            IAZOTokenFee,
            true
        );

        // Setup initialization variables
        address[2] memory _addresses = [address(IAZO_SETTINGS), address(IAZO_LIQUIDITY_LOCKER)];
        address payable[2] memory _addressesPayable = [_IAZOOwner, IAZO_SETTINGS.getFeeAddress()];
        uint256[12] memory _uint256s = [params.TOKEN_PRICE, params.AMOUNT, hardcap, params.SOFTCAP, params.MAX_SPEND_PER_BUYER, params.LIQUIDITY_PERCENT, params.LISTING_PRICE, params.START_TIME, params.ACTIVE_TIME, params.LOCK_PERIOD, IAZO_SETTINGS.getBaseFee(), IAZOTokenFee];
        bool[1] memory _bools = [_burnRemains];
        ERC20[2] memory _ERC20s = [_IAZOToken, _baseToken];
        // Deploy clone contract and set implementation to current IAZO version. "We recommend explicitly describing the risks of participating in malicious sales as Factory is meant to be used without constant admin intervention."
        IIAZO newIAZO = IIAZO(Clones.clone(address(IAZOImplementations[IAZOVersion])));
        newIAZO.initialize(_addresses, _addressesPayable, _uint256s, _bools, _ERC20s, WNative);
        IAZO_EXPOSER.registerIAZO(address(newIAZO));
        _IAZOToken.transferFrom(address(msg.sender), address(newIAZO), tokensRequired);
        // transfer check and reflect token protection
        require(_IAZOToken.balanceOf(address(newIAZO)) == tokensRequired, 'invalid amount transferred in');
        emit IAZOCreated(address(newIAZO));
    }

    /// @notice Creates new IAZO and adds address to IAZOExposer
    /// @param _amount The amount of tokens for sale
    /// @param _tokenPrice The price of a single token
    /// @return Hardcap of the IAZO
    function getHardCap(
        uint256 _amount, 
        uint256 _tokenPrice
    ) public pure returns (uint256) {
        uint256 hardcap = _amount * _tokenPrice / 1e18;
        return hardcap;
    }

    /// @notice Check for how many tokens are required for the IAZO including token sale and liquidity.
    /// @param _amount The amount of tokens for sale
    /// @param _tokenPrice The price of the IAZO token in base token for sale during IAZO
    /// @param _listingPrice The price of the IAZO token in base token when creating liquidity
    /// @param _liquidityPercent The price of a single token
    /// @return Amount of tokens required
    function getTokensRequired(
        uint256 _amount, 
        uint256 _tokenPrice, 
        uint256 _listingPrice, 
        uint256 _liquidityPercent
    ) external view returns (uint256) {
        uint256 IAZOTokenFee = IAZO_SETTINGS.getIAZOTokenFee();
        return _getTokensRequired(_amount, _tokenPrice, _listingPrice, _liquidityPercent, IAZOTokenFee, false);
    }

    function _getTokensRequired(
        uint256 _amount, 
        uint256 _tokenPrice, 
        uint256 _listingPrice, 
        uint256 _liquidityPercent,  
        uint256 _iazoTokenFee,
        bool _require
    ) internal pure returns (uint256) {
        uint256 liquidityRequired = _amount * _tokenPrice * _liquidityPercent / 1000 / _listingPrice;
        /// @dev If liquidityRequired is zero, then there is a likely an issue with the pricing
        if(liquidityRequired == 0) {
            if(_require){
                require(liquidityRequired > 0, "Something wrong with liquidity values");
            } else {
                return 0;
            }
        }
        uint256 iazoTokenFee = _amount * _iazoTokenFee  / 1000;
        uint256 tokensRequired = _amount + liquidityRequired + iazoTokenFee;
        return tokensRequired;
    }

    /// @notice Add and use new IAZO implementation
    /// @param _newIAZOImplementation The address of the new IAZO implementation
    function pushIAZOVersion(IIAZO _newIAZOImplementation) external onlyOwner {
        require(_newIAZOImplementation.isIAZO(), 'implementation does not appear to be IAZO');
        IAZOImplementations.push(_newIAZOImplementation);
        IAZOVersion = IAZOImplementations.length - 1;
        emit PushIAZOVersion(_newIAZOImplementation, IAZOVersion);
    }

    /// @notice Use older IAZO implementation
    /// @dev Owner should be behind a timelock to prevent front running new IAZO deployments
    /// @param _newIAZOVersion The index of the to use IAZO implementation
    function setIAZOVersion(uint256 _newIAZOVersion) external onlyOwner {
        require(_newIAZOVersion < IAZOImplementations.length, 'version out of bounds');
        uint256 previousVersion = IAZOVersion;
        IAZOVersion = _newIAZOVersion;
        emit UpdateIAZOVersion(previousVersion, IAZOVersion);
    }

    /// @notice A public function to sweep accidental ERC20 transfers to this contract. 
    /// @param _tokens Array of ERC20 addresses to sweep
    /// @param _to Address to send tokens to
    function sweepTokens(IERC20[] memory _tokens, address _to) external onlyOwner {
        for (uint256 index = 0; index < _tokens.length; index++) {
            IERC20 token = _tokens[index];
            uint256 balance = token.balanceOf(address(this));
            token.transfer(_to, balance);
            emit SweepWithdraw(_to, token, balance);
        }
    }
}
