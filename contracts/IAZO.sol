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

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "./interface/ERC20.sol";
import "./interface/IWNative.sol";
import "./interface/IIAZOSettings.sol";
import "./interface/IIAZOLiquidityLocker.sol";


/**
 *  Welcome to the "Initial Ape Zone Offering" (IAZO) contract
 */
/// @title IAZO
/// @author ApeSwapFinance
/// @notice IAZO contract where to buy the tokens from
contract IAZO is Initializable {
    using SafeERC20 for ERC20;

    event ForceFailed(address indexed by);
    event UpdateMaxSpendLimit(uint256 previousMaxSpend, uint256 newMaxSpend);
    event FeesCollected(address indexed feeAddress, uint256 baseFeeCollected, uint256 IAZOTokenFee);
    event UpdateIAZOBlocks(uint256 previousStartTime, uint256 newStartBlock, uint256 previousActiveTime, uint256 newActiveBlocks);
    event AddLiquidity(uint256 baseLiquidity, uint256 saleTokenLiquidity, uint256 remainingBaseBalance);
    event SweepWithdraw(
        address indexed receiver, 
        IERC20 indexed token, 
        uint256 balance
    );
    event UserWithdrawSuccess(address _address, uint256 _amount);
    event UserWithdrawFailed(address _address, uint256 _amount);
    event UserDeposited(address _address, uint256 _amount);

    struct IAZOInfo {
        address payable IAZO_OWNER; //IAZO_OWNER address
        ERC20 IAZO_TOKEN; // token offered for IAZO
        ERC20 BASE_TOKEN; // token to buy IAZO_TOKEN
        bool IAZO_SALE_IN_NATIVE; // IAZO sale in NATIVE or ERC20.
        uint256 TOKEN_PRICE; // cost for 1 IAZO_TOKEN in BASE_TOKEN (or NATIVE)
        uint256 AMOUNT; // amount of IAZO_TOKENS for sale
        uint256 HARDCAP; // hardcap of earnings.
        uint256 SOFTCAP; // softcap for earning. if not reached IAZO is cancelled 
        uint256 MAX_SPEND_PER_BUYER; // max spend per buyer
        uint256 LIQUIDITY_PERCENT; // 1 = 0.1%
        uint256 LISTING_PRICE; // fixed rate at which the token will list on apeswap
        bool BURN_REMAINS;
    }

    struct IAZOTimeInfo {
        uint256 START_TIME; // block to start IAZO
        uint256 ACTIVE_TIME; // end of IAZO -> block.timestamp + ACTIVE_TIME
        uint256 LOCK_PERIOD; // unix timestamp (3 weeks) to lock earned tokens for IAZO_OWNER
    }

    struct IAZOStatus {
        bool LP_GENERATION_COMPLETE; // final flag required to end a iazo and enable withdrawls
        bool FORCE_FAILED; // set this flag to force fail the iazo
        uint256 TOTAL_BASE_COLLECTED; // total base currency raised (usually ETH)
        uint256 TOTAL_TOKENS_SOLD; // total iazo tokens sold
        uint256 TOTAL_TOKENS_WITHDRAWN; // total tokens withdrawn post successful iazo
        uint256 TOTAL_BASE_WITHDRAWN; // total base tokens withdrawn on iazo failure
        uint256 NUM_BUYERS; // number of unique participants
    }

    struct BuyerInfo {
        uint256 deposited; // deposited base tokens, if IAZO fails these can be withdrawn
        uint256 tokensBought; // bought tokens. can be withdrawn on iazo success
    }

    struct FeeInfo {
        address payable FEE_ADDRESS;
        uint256 BASE_FEE; // 1 = 0.1%
        uint256 IAZO_TOKEN_FEE; // 1 = 0.1%
    }

    bool constant public isIAZO = true;

    // structs
    IAZOInfo public IAZO_INFO;
    IAZOTimeInfo public IAZO_TIME_INFO;
    IAZOStatus public STATUS;
    FeeInfo public FEE_INFO;
    // contracts
    IIAZOSettings public IAZO_SETTINGS;
    IIAZOLiquidityLocker public IAZO_LIQUIDITY_LOCKER;
    IWNative ERC20Mock;
    /// @dev reference variable
    address public IAZO_FACTORY;
    // addresses
    address public TOKEN_LOCK_ADDRESS = 0x0000000000000000000000000000000000000000;
    // BuyerInfo mapping
    mapping(address => BuyerInfo) public BUYERS;

    // _addresses = [IAZOSettings, IAZOLiquidityLocker]
    // _addressesPayable = [IAZOOwner, feeAddress]
    // _uint256s = [_tokenPrice,  _amount, _hardcap,  _softcap, _maxSpendPerBuyer, _liquidityPercent, _listingPrice, _startTime, _activeTime, _lockPeriod, _baseFee, iazoTokenFee]
    // _bools = [_burnRemains]
    // _ERC20s = [_iazoToken, _baseToken]
    /// @notice Initialization of IAZO
    function initialize(
        address[2] memory _addresses, 
        address payable[2] memory _addressesPayable, 
        uint256[12] memory _uint256s, 
        bool[1] memory _bools, 
        ERC20[2] memory _ERC20s, 
        IWNative _wnative
    ) external initializer {
        IAZO_FACTORY = msg.sender;
        ERC20Mock = _wnative;

        IAZO_SETTINGS = IIAZOSettings(_addresses[0]);
        IAZO_LIQUIDITY_LOCKER = IIAZOLiquidityLocker(_addresses[1]);

        IAZO_INFO.IAZO_OWNER = _addressesPayable[0]; // User which created the IAZO
        FEE_INFO.FEE_ADDRESS = _addressesPayable[1];

        IAZO_INFO.IAZO_SALE_IN_NATIVE = address(_ERC20s[1]) == address(ERC20Mock) ? true : false;
        IAZO_INFO.TOKEN_PRICE = _uint256s[0]; // Price of time in base currency
        IAZO_INFO.AMOUNT = _uint256s[1]; // Amount of tokens for sale
        IAZO_INFO.HARDCAP = _uint256s[2]; // Hardcap base token to collect (TOKEN_PRICE * AMOUNT)
        IAZO_INFO.SOFTCAP = _uint256s[3]; // Minimum amount of base tokens to collect for succesfull IAZO
        IAZO_INFO.MAX_SPEND_PER_BUYER = _uint256s[4]; // Max amount of base tokens that can be used to purchase IAZO token per account
        IAZO_INFO.LIQUIDITY_PERCENT = _uint256s[5]; // Percentage of liquidity to lock after IAZO
        IAZO_INFO.LISTING_PRICE = _uint256s[6]; // The rate to be listed for liquidity
        IAZO_TIME_INFO.START_TIME = _uint256s[7];
        IAZO_TIME_INFO.ACTIVE_TIME = _uint256s[8];
        IAZO_TIME_INFO.LOCK_PERIOD = _uint256s[9];
        FEE_INFO.BASE_FEE = _uint256s[10];
        FEE_INFO.IAZO_TOKEN_FEE = _uint256s[11];

        IAZO_INFO.BURN_REMAINS = _bools[0]; // Burn remainder of IAZO tokens not sold

        IAZO_INFO.IAZO_TOKEN = _ERC20s[0]; // Token for sale 
        IAZO_INFO.BASE_TOKEN = _ERC20s[1]; // Token used to buy IAZO token
    }

    /// @notice Modifier: Only allow admin address to call certain functions
    modifier onlyAdmin() {
        require(IAZO_SETTINGS.isAdmin(msg.sender), "Admin only");
        _;
    }

    /// @notice Modifier: Only allow IAZO owner address to call certain functions
    modifier onlyIAZOOwner() {
        require(msg.sender == IAZO_INFO.IAZO_OWNER, "IAZO owner only");
        _;
    }

    /// @notice Modifier: Only allow IAZO owner address to call certain functions
    modifier onlyIAZOFactory() {
        require(msg.sender == IAZO_FACTORY, "IAZO_FACTORY only");
        _;
    }

    /// @notice The state of the IAZO
    /// @return The state of the IAZO
    function getIAZOState() public view returns (uint256) {
        // 4 FAILED - force fail
        if (STATUS.FORCE_FAILED) return 4; 
        // 4 FAILED - softcap not met by end block
        if ((block.timestamp > IAZO_TIME_INFO.START_TIME + IAZO_TIME_INFO.ACTIVE_TIME) && (STATUS.TOTAL_BASE_COLLECTED < IAZO_INFO.SOFTCAP)) return 4; 
        // 3 SUCCESS - hardcap met
        if (STATUS.TOTAL_BASE_COLLECTED >= IAZO_INFO.HARDCAP) return 3; 
        // 2 SUCCESS - endblock and soft cap reached
        if ((block.timestamp > IAZO_TIME_INFO.START_TIME + IAZO_TIME_INFO.ACTIVE_TIME) && (STATUS.TOTAL_BASE_COLLECTED >= IAZO_INFO.SOFTCAP)) return 2; 
        // 1 ACTIVE - deposits enabled
        if ((block.timestamp >= IAZO_TIME_INFO.START_TIME) && (block.timestamp <= IAZO_TIME_INFO.START_TIME + IAZO_TIME_INFO.ACTIVE_TIME)) return 1; 
        // 0 QUEUED - awaiting start block
        return 0; 
    }

    /// @notice Buy IAZO tokens with native coin
    function userDepositNative () external payable {
        require(IAZO_INFO.IAZO_SALE_IN_NATIVE, "not a native token IAZO");
        userDepositPrivate(msg.value);
    }

    /// @notice Buy IAZO tokens with base token
    /// @param _amount Amount of base tokens to use to buy IAZO tokens for
    function userDeposit (uint256 _amount) external {
        require(!IAZO_INFO.IAZO_SALE_IN_NATIVE, "cannot deposit tokens in a native token sale");
        userDepositPrivate(_amount);
    }

    /// @notice Internal function used to buy IAZO tokens in either native coin or base token
    /// @param _amount Amount of base tokens to use to buy IAZO tokens for
    function userDepositPrivate (uint256 _amount) private {
        // Check that IAZO is in the ACTIVE state for user deposits
        require(getIAZOState() == 1, 'IAZO not active');
        BuyerInfo storage buyer = BUYERS[msg.sender];

        uint256 amount_in = IAZO_INFO.IAZO_SALE_IN_NATIVE ? msg.value : _amount;
        uint256 allowance = IAZO_INFO.MAX_SPEND_PER_BUYER - buyer.deposited;
        uint256 remaining = IAZO_INFO.HARDCAP - STATUS.TOTAL_BASE_COLLECTED;
        allowance = allowance > remaining ? remaining : allowance;
        if (amount_in > allowance) {
            amount_in = allowance;
        }

        uint256 tokensSold = amount_in * (10 ** uint256(IAZO_INFO.IAZO_TOKEN.decimals())) / IAZO_INFO.TOKEN_PRICE;
        require(tokensSold > 0, '0 tokens bought');
        if (buyer.deposited == 0) {
            STATUS.NUM_BUYERS++;
        }
        buyer.deposited += amount_in;
        buyer.tokensBought += tokensSold;
        STATUS.TOTAL_BASE_COLLECTED += amount_in;
        STATUS.TOTAL_TOKENS_SOLD += tokensSold;
        
        // return unused NATIVE tokens
        if (IAZO_INFO.IAZO_SALE_IN_NATIVE && amount_in < msg.value) {
            payable(msg.sender).transfer(msg.value - amount_in);
        }
        // deduct non NATIVE token from user
        if (!IAZO_INFO.IAZO_SALE_IN_NATIVE) {
            IAZO_INFO.BASE_TOKEN.safeTransferFrom(msg.sender, address(this), amount_in);
        }
        emit UserDeposited(msg.sender, amount_in);
    }

    /// @notice The function users call to withdraw funds
    function userWithdraw() external {
        uint256 currentIAZOState = getIAZOState();
        require(
            currentIAZOState == 2 || // SUCCESS
            currentIAZOState == 3 || // HARD_CAP_MET
            currentIAZOState == 4,   // FAILED 
            'Invalid IAZO state withdraw'
        );
       
       // Failed
       if(currentIAZOState == 4) { 
           userWithdrawFailedPrivate();
       }
        // Success / hardcap met
       if(currentIAZOState == 2 || currentIAZOState == 3) { 
           userWithdrawSuccessPrivate();
       }
    }

    function userWithdrawSuccessPrivate() private {
        if(!STATUS.LP_GENERATION_COMPLETE){
            addLiquidity();
        }
        BuyerInfo storage buyer = BUYERS[msg.sender];
        require(buyer.tokensBought > 0, 'Nothing to withdraw');
        STATUS.TOTAL_TOKENS_WITHDRAWN += buyer.tokensBought;
        uint256 tokensToTransfer = buyer.tokensBought;
        buyer.tokensBought = 0;
        IAZO_INFO.IAZO_TOKEN.safeTransfer(msg.sender, tokensToTransfer);
        emit UserWithdrawSuccess(msg.sender, tokensToTransfer);
    }

    function userWithdrawFailedPrivate() private {
        BuyerInfo storage buyer = BUYERS[msg.sender];
        require(buyer.deposited > 0, 'Nothing to withdraw');
        STATUS.TOTAL_BASE_WITHDRAWN += buyer.deposited;
        uint256 tokensToTransfer = buyer.deposited;
        buyer.deposited = 0;
        
        if(IAZO_INFO.IAZO_SALE_IN_NATIVE){
            payable(msg.sender).transfer(tokensToTransfer);
        } else {
            IAZO_INFO.BASE_TOKEN.safeTransfer(msg.sender, tokensToTransfer);
        }
        emit UserWithdrawFailed(msg.sender, tokensToTransfer);
    }

    /**
     * onlyAdmin functions
     */

    function forceFailAdmin() external onlyAdmin {
        STATUS.FORCE_FAILED = true;
        emit ForceFailed(msg.sender);
    }

    /**
     * onlyIAZOOwner functions
     */

    /// @notice Change start and end of IAZO
    /// @param _startTime New start time of IAZO
    /// @param _activeTime New active time of IAZO
    function updateStart(uint256 _startTime, uint256 _activeTime) external onlyIAZOOwner {
        require(IAZO_TIME_INFO.START_TIME > block.timestamp, "IAZO has already started");
        require(_startTime > block.timestamp, "Start time must be in future");
        require(_activeTime >= IAZO_SETTINGS.getMinIAZOLength(), "Active iazo not long enough");
        uint256 previousStartTime = IAZO_TIME_INFO.START_TIME;
        IAZO_TIME_INFO.START_TIME = _startTime;

        uint256 previousActiveTime = IAZO_TIME_INFO.ACTIVE_TIME;
        IAZO_TIME_INFO.ACTIVE_TIME = _activeTime;
        emit UpdateIAZOBlocks(previousStartTime, IAZO_TIME_INFO.START_TIME, previousActiveTime, IAZO_TIME_INFO.ACTIVE_TIME);
    }

    /// @notice Change the max spend limit for a buyer
    /// @param _maxSpend New spend limit
    function updateMaxSpendLimit(uint256 _maxSpend) external onlyIAZOOwner {
        uint256 previousMaxSpend = IAZO_INFO.MAX_SPEND_PER_BUYER;
        IAZO_INFO.MAX_SPEND_PER_BUYER = _maxSpend;
        emit UpdateMaxSpendLimit(previousMaxSpend, IAZO_INFO.MAX_SPEND_PER_BUYER);
    }

    /// @notice Final step when IAZO is successfull. lock liquidity and enable withdrawals of sale token.
    function addLiquidity() public { 
        require(!STATUS.LP_GENERATION_COMPLETE, 'LP Generation is already complete');
        uint256 currentIAZOState = getIAZOState();
        // Check if IAZO SUCCESS or HARDCAT met
        require(currentIAZOState == 2 || currentIAZOState == 3, 'IAZO failed or still in progress'); // SUCCESS

        // If pair for this token has already been initalized, then this will fail the IAZO
        if (IAZO_LIQUIDITY_LOCKER.apePairIsInitialised(address(IAZO_INFO.IAZO_TOKEN), address(IAZO_INFO.BASE_TOKEN))) {
            STATUS.FORCE_FAILED = true;
            return;
        }

        //calculate fees
        uint256 apeswapBaseFee = STATUS.TOTAL_BASE_COLLECTED * FEE_INFO.BASE_FEE / 1000;
        uint256 apeswapIAZOTokenFee = STATUS.TOTAL_TOKENS_SOLD * FEE_INFO.IAZO_TOKEN_FEE / 1000;
                
        // base token liquidity
        uint256 baseLiquidity = STATUS.TOTAL_BASE_COLLECTED  * IAZO_INFO.LIQUIDITY_PERCENT / 1000;
        
        // deposit NATIVE to recieve ERC20Mock tokens
        if (IAZO_INFO.IAZO_SALE_IN_NATIVE) {
            ERC20Mock.deposit{value : baseLiquidity}();
        }

        IAZO_INFO.BASE_TOKEN.approve(address(IAZO_LIQUIDITY_LOCKER), baseLiquidity);

        // sale token liquidity
        uint256 saleTokenLiquidity = baseLiquidity * (10 ** IAZO_INFO.IAZO_TOKEN.decimals()) / IAZO_INFO.LISTING_PRICE;
        IAZO_INFO.IAZO_TOKEN.approve(address(IAZO_LIQUIDITY_LOCKER), saleTokenLiquidity);

        address newTokenLockContract = IAZO_LIQUIDITY_LOCKER.lockLiquidity(
            IAZO_INFO.BASE_TOKEN, 
            IAZO_INFO.IAZO_TOKEN, 
            baseLiquidity, 
            saleTokenLiquidity, 
            block.timestamp + IAZO_TIME_INFO.LOCK_PERIOD, 
            IAZO_INFO.IAZO_OWNER,
            address(this)
        );
        TOKEN_LOCK_ADDRESS = newTokenLockContract;

        STATUS.LP_GENERATION_COMPLETE = true;

        if(IAZO_INFO.IAZO_SALE_IN_NATIVE){
            FEE_INFO.FEE_ADDRESS.transfer(apeswapBaseFee);
        } else { 
            IAZO_INFO.BASE_TOKEN.safeTransfer(FEE_INFO.FEE_ADDRESS, apeswapBaseFee);
        }
        IAZO_INFO.IAZO_TOKEN.safeTransfer(FEE_INFO.FEE_ADDRESS, apeswapIAZOTokenFee);
        emit FeesCollected(FEE_INFO.FEE_ADDRESS, apeswapBaseFee, apeswapIAZOTokenFee);

        // send remaining iazo tokens to iazo owner
        uint256 remainingIAZOTokenBalance = IAZO_INFO.IAZO_TOKEN.balanceOf(address(this));
        if (remainingIAZOTokenBalance > STATUS.TOTAL_TOKENS_SOLD) {
            uint256 amountLeft = remainingIAZOTokenBalance - STATUS.TOTAL_TOKENS_SOLD;
            if(IAZO_INFO.BURN_REMAINS){
                IAZO_INFO.IAZO_TOKEN.safeTransfer(IAZO_SETTINGS.getBurnAddress(), amountLeft);
            } else {
                IAZO_INFO.IAZO_TOKEN.safeTransfer(IAZO_INFO.IAZO_OWNER, amountLeft);
            }
        }
        
        // send remaining base tokens to iazo owner
        uint256 remainingBaseBalance = IAZO_INFO.IAZO_SALE_IN_NATIVE ? address(this).balance : IAZO_INFO.BASE_TOKEN.balanceOf(address(this));
        
        if(IAZO_INFO.IAZO_SALE_IN_NATIVE){
            IAZO_INFO.IAZO_OWNER.transfer(remainingBaseBalance);
        } else {
            IAZO_INFO.BASE_TOKEN.safeTransfer(IAZO_INFO.IAZO_OWNER, remainingBaseBalance);
        }
        
        emit AddLiquidity(baseLiquidity, saleTokenLiquidity, remainingBaseBalance);

    }

    /// @notice A public function to sweep accidental ERC20 transfers to this contract. 
    ///   Tokens are sent to owner
    /// @param token The address of the ERC20 token to sweep
    function sweepToken(IERC20 token) external onlyAdmin {
        require(token != IAZO_INFO.IAZO_TOKEN, "cannot sweep IAZO_TOKEN");
        require(token != IAZO_INFO.BASE_TOKEN, "cannot sweep BASE_TOKEN");
        uint256 balance = token.balanceOf(address(this));
        token.transfer(msg.sender, balance);
        emit SweepWithdraw(msg.sender, token, balance);
    }
}