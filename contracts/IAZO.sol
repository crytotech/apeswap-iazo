//SPDX-License-Identifier: UNLICENSED
//ALL RIGHTS RESERVED
//apeswap.finance

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

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interface/ERC20.sol";
import "./interface/IWBNB.sol";
import "./interface/IIAZOSettings.sol";
import "./interface/IIAZOLiquidityLocker.sol";
// TODO: Add sweep token functionality 

/**
 *  Welcome to the "Initial Ape Zone Offering" (IAZO) contract
 */

contract IAZO {
    using SafeERC20 for ERC20;

    event ForceFailed(address indexed by);
    event UpdateMaxSpendLimit(uint256 previousMaxSpend, uint256 newMaxSpend);
    event BaseFeeCollected(address indexed feeAddress, uint256 baseFeeCollected);
    event UpdateIAZOBlocks(uint256 previousStartBlock, uint256 newStartBlock, uint256 previousActiveBlocks, uint256 newActiveBlocks);
    event AddLiquidity(uint256 baseLiquidity, uint256 saleTokenLiquidity, uint256 remainingBaseBalance);


    struct IAZOInfo {
        address payable IAZO_OWNER; //IAZO_OWNER address
        ERC20 IAZO_TOKEN; // token offered for IAZO
        ERC20 BASE_TOKEN; // token to buy IAZO_TOKEN
        bool IAZO_SALE_IN_BNB; // IAZO sale in bnb or BEP20.
        uint256 TOKEN_PRICE; // cost for 1 IAZO_TOKEN in BASE_TOKEN (or BNB)
        uint256 AMOUNT; // amount of IAZO_TOKENS for sale
        uint256 HARDCAP; // hardcap of earnings.
        uint256 SOFTCAP; // softcap for earning. if not reached IAZO is cancelled 
        uint256 MAX_SPEND_PER_BUYER; // max spend per buyer
        uint256 LIQUIDITY_PERCENT; // divided by 1000
        uint256 LISTING_PRICE; // fixed rate at which the token will list on apeswap
        bool BURN_REMAINS;
    }

    struct IAZOTimeInfo {
        uint256 START_BLOCK; // block to start IAZO
        uint256 ACTIVE_BLOCKS; // end of IAZO -> START_BLOCK + ACTIVE_BLOCKS
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
        bool PREPAID_FEE;
        uint256 BASE_FEE; // divided by 100
    }
    
    enum IAZOState{ 
        QUEUED, 
        ACTIVE, 
        SUCCESS, 
        HARDCAP_MET, 
        FAILED 
    }

    // structs
    IAZOInfo public IAZO_INFO;
    IAZOTimeInfo public IAZO_TIME_INFO;
    IAZOStatus public STATUS;
    FeeInfo public FEE_INFO;
    // contracts
    IIAZOSettings public IAZO_SETTINGS;
    IIAZOLiquidityLocker public IAZO_LIQUIDITY_LOCKER;
    IWBNB WBNB;
    /// @dev reference variable
    address public IAZO_FACTORY;
    // addresses
    address public BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    address public TOKEN_LOCK_ADDRESS = 0x0000000000000000000000000000000000000000;
    // BuyerInfo mapping
    mapping(address => BuyerInfo) public BUYERS;


    constructor(address _IAZOSettings, address _IAZOLiquidityLocker, address _wbnb) {
        IAZO_FACTORY = msg.sender;
        IAZO_SETTINGS = IIAZOSettings(_IAZOSettings);
        IAZO_LIQUIDITY_LOCKER = IIAZOLiquidityLocker(_IAZOLiquidityLocker);
        WBNB = IWBNB(_wbnb);
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

    function initializeIAZO(
        address payable _iazoOwner,
        ERC20 _iazoToken,
        ERC20 _baseToken,
        uint256 _tokenPrice, 
        uint256 _amount,
        uint256 _hardcap, 
        uint256 _softcap,
        uint256 _maxSpendPerBuyer,
        uint256 _liquidityPercent,
        // TODO: What is _listingRate vs _tokenPrice?
        uint256 _listingRate
    ) external onlyIAZOFactory {
        // TODO: Add require statement to verify tokens are not the same or address(0)
        IAZO_INFO.IAZO_OWNER = _iazoOwner;
        IAZO_INFO.IAZO_TOKEN = _iazoToken;
        IAZO_INFO.BASE_TOKEN = _baseToken;
        // TODO: Passing WBNB address for BNB IAZO? 
        IAZO_INFO.IAZO_SALE_IN_BNB = address(_baseToken) == address(WBNB) ? true : false;
        // NOTE: Price of token in the base currency? 
        IAZO_INFO.TOKEN_PRICE = _tokenPrice;
        // TODO: Amount?
        IAZO_INFO.AMOUNT = _amount;
        IAZO_INFO.HARDCAP = _hardcap;
        IAZO_INFO.SOFTCAP = _softcap;
        IAZO_INFO.MAX_SPEND_PER_BUYER = _maxSpendPerBuyer;
        IAZO_INFO.LIQUIDITY_PERCENT = _liquidityPercent;
        IAZO_INFO.LISTING_PRICE = _listingRate;
    }

    function initializeIAZO2(
        uint256 _startBlock,
        uint256 _activeBlocks,
        uint256 _lockPeriod,
        bool _prepaidFee,
        bool _burnRemains,
        address payable _feeAddress,
        uint256 _baseFee
    ) external onlyIAZOFactory {
        IAZO_TIME_INFO.START_BLOCK = _startBlock;
        IAZO_TIME_INFO.ACTIVE_BLOCKS = _activeBlocks;
        IAZO_TIME_INFO.LOCK_PERIOD = _lockPeriod;
        IAZO_INFO.BURN_REMAINS = _burnRemains;
        FEE_INFO.PREPAID_FEE = _prepaidFee;
        FEE_INFO.FEE_ADDRESS = _feeAddress;
        FEE_INFO.BASE_FEE = _baseFee;
    }

    function getIAZOState() public view returns (IAZOState) {
        // 5 FAILED - force fail
        if (STATUS.FORCE_FAILED) return IAZOState.FAILED; 
        // 4 FAILED - softcap not met by end block
        if ((block.number > IAZO_TIME_INFO.START_BLOCK + IAZO_TIME_INFO.ACTIVE_BLOCKS) && (STATUS.TOTAL_BASE_COLLECTED < IAZO_INFO.SOFTCAP)) return IAZOState.FAILED; 
        // 3 SUCCESS - hardcap met
        if (STATUS.TOTAL_BASE_COLLECTED >= IAZO_INFO.HARDCAP) return IAZOState.HARDCAP_MET; 
        // TODO: Do we need to wait until the liquidity is created?
        // 2 SUCCESS - endblock and soft cap reached
        // TODO: Use a timestamp?
        if ((block.number > IAZO_TIME_INFO.START_BLOCK + IAZO_TIME_INFO.ACTIVE_BLOCKS) && (STATUS.TOTAL_BASE_COLLECTED >= IAZO_INFO.SOFTCAP)) return IAZOState.SUCCESS; 
        // 1 ACTIVE - deposits enabled
        if ((block.number >= IAZO_TIME_INFO.START_BLOCK) && (block.number <= IAZO_TIME_INFO.START_BLOCK + IAZO_TIME_INFO.ACTIVE_BLOCKS)) return IAZOState.ACTIVE; 
        // 0 QUEUED - awaiting start block
        return IAZOState.QUEUED; 
    }

    function userDepositNative () external payable {
        require(IAZO_INFO.IAZO_SALE_IN_BNB, "not a native token IAZO");
        userDepositPrivate(msg.value);
    }

    function userDeposit (uint256 _amount) external {
        require(!IAZO_INFO.IAZO_SALE_IN_BNB, "cannot deposit tokens in a native token sale");
        userDepositPrivate(_amount);
    }


    // TODO: It is risky to make a function payable when sometimes it takes tokens. Users could send BNB along with their token deposit 
    function userDepositPrivate (uint256 _amount) private {
        require(getIAZOState() == IAZOState.ACTIVE, 'IAZO not active');
        BuyerInfo storage buyer = BUYERS[msg.sender];

        uint256 amount_in = IAZO_INFO.IAZO_SALE_IN_BNB ? msg.value : _amount;
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
        
        // return unused BNB
        if (IAZO_INFO.IAZO_SALE_IN_BNB && amount_in < msg.value) {
            payable(msg.sender).transfer(msg.value - amount_in);
        }
        // deduct non BNB token from user
        if (!IAZO_INFO.IAZO_SALE_IN_BNB) {
            IAZO_INFO.BASE_TOKEN.safeTransferFrom(msg.sender, address(this), amount_in);
        }
    }

    /// @notice The function users call to withdraw funds
    function userWithdraw() external {
        IAZOState currentIAZOState = getIAZOState();
        // TODO: Combine HARDCAP_MET and SUCCESS?
        require(
            currentIAZOState == IAZOState.SUCCESS || 
            currentIAZOState == IAZOState.HARDCAP_MET || 
            currentIAZOState == IAZOState.FAILED, 
            'Invalid IAZO state withdraw'
        );
       
       // TODO: Can user funds be removed?
       // Failed
       if(currentIAZOState == IAZOState.FAILED){ 
           userWithdrawFailedPrivate();
       }
        // Success
       if(currentIAZOState == IAZOState.SUCCESS || currentIAZOState == IAZOState.HARDCAP_MET){ 
           userWithdrawSuccessPrivate();
       }
    }

    function userWithdrawSuccessPrivate() private {
        require(STATUS.LP_GENERATION_COMPLETE, 'Awaiting LP generation');
        BuyerInfo storage buyer = BUYERS[msg.sender];
        require(buyer.tokensBought > 0, 'Nothing to withdraw');
        STATUS.TOTAL_TOKENS_WITHDRAWN += buyer.tokensBought;
        buyer.tokensBought = 0;
        IAZO_INFO.IAZO_TOKEN.safeTransfer(msg.sender, buyer.tokensBought);
    }

    function userWithdrawFailedPrivate() private {
        BuyerInfo storage buyer = BUYERS[msg.sender];
        require(buyer.deposited > 0, 'Nothing to withdraw');
        STATUS.TOTAL_BASE_WITHDRAWN += buyer.deposited;
        buyer.deposited = 0;
        
        if(IAZO_INFO.IAZO_SALE_IN_BNB){
            payable(msg.sender).transfer(buyer.deposited);
        } else {
            IAZO_INFO.BASE_TOKEN.safeTransfer(msg.sender, buyer.deposited);
        }
    }

    function forceFailAdmin() external onlyAdmin {
        STATUS.FORCE_FAILED = true;
        emit ForceFailed(msg.sender);
    }

    // Change start and end of IAZO
    function updateStart(uint256 _startBlock, uint256 _activeBlocks) external onlyIAZOOwner {
        require(IAZO_TIME_INFO.START_BLOCK > block.number, "IAZO has already starteds");
        require(_startBlock > block.number, "Start block must be in future");
        require(_activeBlocks >= IAZO_SETTINGS.getMinIAZOLength(), "Active iazo not long enough");
        uint256 previousStartBlock = IAZO_TIME_INFO.START_BLOCK;
        IAZO_TIME_INFO.START_BLOCK = _startBlock;

        uint256 previousActiveBlocks = IAZO_TIME_INFO.ACTIVE_BLOCKS;
        IAZO_TIME_INFO.ACTIVE_BLOCKS = _activeBlocks;
        emit UpdateIAZOBlocks(previousStartBlock, IAZO_TIME_INFO.START_BLOCK, previousActiveBlocks, IAZO_TIME_INFO.ACTIVE_BLOCKS);
    }

    function updateMaxSpendLimit(uint256 _maxSpend) external onlyIAZOOwner {
        uint256 previousMaxSpend = IAZO_INFO.MAX_SPEND_PER_BUYER;
        IAZO_INFO.MAX_SPEND_PER_BUYER = _maxSpend;
        emit UpdateMaxSpendLimit(previousMaxSpend, IAZO_INFO.MAX_SPEND_PER_BUYER);
    }

    // TODO: Review function
    //final step when iazo is successfull. lock liquidity and enable withdrawals of sale token.
    function addLiquidity() external {      
        require(!STATUS.LP_GENERATION_COMPLETE, 'GENERATION COMPLETE');
        IAZOState currentIAZOState = getIAZOState();
        require(currentIAZOState == IAZOState.SUCCESS || currentIAZOState == IAZOState.HARDCAP_MET, 'IAZO failed or still in progress'); // SUCCESS

        // FIXME: IF pair is initalized and has tokens in it before it gets here this will short circuit 
        // FIXME: If this is going to be open to the public, we need to evaluate if tokens will get locked in the contract
        // FIXME: If this goes into FORCE_FAILED then the entire IAZO won't work 
        if (IAZO_LIQUIDITY_LOCKER.apePairIsInitialised(address(IAZO_INFO.IAZO_TOKEN), address(IAZO_INFO.BASE_TOKEN))) {
            STATUS.FORCE_FAILED = true;
            return;
        }

        uint256 apeswapBaseFee = FEE_INFO.PREPAID_FEE ? 0 : STATUS.TOTAL_BASE_COLLECTED * FEE_INFO.BASE_FEE / 100;
                
        // base token liquidity
        uint256 baseLiquidity = (STATUS.TOTAL_BASE_COLLECTED - apeswapBaseFee) * IAZO_INFO.LIQUIDITY_PERCENT / 100;
        
        // deposit BNB to recieve WBNB tokens
        if (IAZO_INFO.IAZO_SALE_IN_BNB) {
            WBNB.deposit{value : baseLiquidity}();
        }

        IAZO_INFO.BASE_TOKEN.approve(address(IAZO_LIQUIDITY_LOCKER), baseLiquidity);

        // sale token liquidity
        uint256 saleTokenLiquidity = baseLiquidity * (10 ** IAZO_INFO.IAZO_TOKEN.decimals()) / IAZO_INFO.LISTING_PRICE;
        IAZO_INFO.IAZO_TOKEN.approve(address(IAZO_LIQUIDITY_LOCKER), saleTokenLiquidity);

        // TODO: Pass IAZO settings address for access control?
        // TODO: Save token lock contract in this contract
        address newTokenLockContract = IAZO_LIQUIDITY_LOCKER.lockLiquidity(
            IAZO_INFO.BASE_TOKEN, 
            IAZO_INFO.IAZO_TOKEN, 
            baseLiquidity, 
            saleTokenLiquidity, 
            block.timestamp + IAZO_TIME_INFO.LOCK_PERIOD, 
            IAZO_INFO.IAZO_OWNER, 
            IAZO_SETTINGS.getAdminAddress()
        );
        TOKEN_LOCK_ADDRESS = newTokenLockContract;

        if(!FEE_INFO.PREPAID_FEE)
        {
            if(IAZO_INFO.IAZO_SALE_IN_BNB){
                FEE_INFO.FEE_ADDRESS.transfer(apeswapBaseFee);
            } else { 
                IAZO_INFO.BASE_TOKEN.transfer(FEE_INFO.FEE_ADDRESS, apeswapBaseFee);
            }
            emit BaseFeeCollected(FEE_INFO.FEE_ADDRESS, apeswapBaseFee);
        }

        // send remaining iazo tokens to iazo owner
        uint256 remainingIAZOTokenBalance = IAZO_INFO.IAZO_TOKEN.balanceOf(address(this));
        if (remainingIAZOTokenBalance > STATUS.TOTAL_TOKENS_SOLD) {
            uint256 amountLeft = remainingIAZOTokenBalance - STATUS.TOTAL_TOKENS_SOLD;
            if(IAZO_INFO.BURN_REMAINS){
                IAZO_INFO.IAZO_TOKEN.safeTransfer(BURN_ADDRESS, amountLeft);
            } else {
                IAZO_INFO.IAZO_TOKEN.safeTransfer(IAZO_INFO.IAZO_OWNER, amountLeft);
            }
        }
        
        // send remaining base tokens to iazo owner
        uint256 remainingBaseBalance = IAZO_INFO.IAZO_SALE_IN_BNB ? address(this).balance : IAZO_INFO.BASE_TOKEN.balanceOf(address(this));
        
        if(IAZO_INFO.IAZO_SALE_IN_BNB){
            IAZO_INFO.IAZO_OWNER.transfer(remainingBaseBalance);
        } else {
            IAZO_INFO.BASE_TOKEN.safeTransfer(IAZO_INFO.IAZO_OWNER, remainingBaseBalance);
        }
        
        STATUS.LP_GENERATION_COMPLETE = true;
        emit AddLiquidity(baseLiquidity, saleTokenLiquidity, remainingBaseBalance);
    }
}
