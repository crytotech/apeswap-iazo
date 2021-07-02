//SPDX-License-Identifier: UNLICENSED
//ALL RIGHTS RESERVED
//apeswap.finance

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interface/ERC20.sol";
import "./interface/IWBNB.sol";
import "./ILOSettings.sol";
import "./LiquidityLocker.sol";
//import "./interface/IILOSettings.sol";

// TODO: Rebrand to IAZO "Initial Ape Zone Offering" 
// TODO: Add sweep token functionality 

contract ILO {
    using SafeERC20 for ERC20;

    event ForceFailed(address indexed by);
    event UpdateMaxSpendLimit(uint256 previousMaxSpend, uint256 newMaxSpend);
    event BaseFeeCollected(address indexed feeAddress, uint256 baseFeeCollected);
    event UpdateILOBlocks(uint256 previousStartBlock, uint256 newStartBlock, uint256 previousActiveBlocks, uint256 newActiveBlocks);
    event AddLiquidity(uint256 baseLiquidity, uint256 saleTokenLiquidity, uint256 remainingBaseBalance);


    struct ILOInfo {
        address payable ILO_OWNER; //ILO_OWNER address
        ERC20 ILO_TOKEN; // token offered for ILO
        ERC20 BASE_TOKEN; // token to buy ILO_TOKEN
        bool ILO_SALE_IN_BNB; // ILO sale in bnb or BEP20.
        uint256 TOKEN_PRICE; // cost for 1 ILO_TOKEN in BASE_TOKEN (or BNB)
        uint256 AMOUNT; // amount of ILO_TOKENS for sale
        uint256 HARDCAP; // hardcap of earnings.
        uint256 SOFTCAP; // softcap for earning. if not reached ILO is cancelled 
        uint256 MAX_SPEND_PER_BUYER; // max spend per buyer
        uint256 LIQUIDITY_PERCENT; // divided by 1000
        uint256 LISTING_PRICE; // fixed rate at which the token will list on apeswap
        bool BURN_REMAINS;
    }

    struct ILOTimeInfo {
        uint256 START_BLOCK; // block to start ILO
        uint256 ACTIVE_BLOCKS; // end of ILO -> START_BLOCK + ACTIVE_BLOCKS
        uint256 LOCK_PERIOD; // unix timestamp (3 weeks) to lock earned tokens for ILO_OWNER
    }

    struct ILOStatus {
        bool LP_GENERATION_COMPLETE; // final flag required to end a ilo and enable withdrawls
        bool FORCE_FAILED; // set this flag to force fail the ilo
        uint256 TOTAL_BASE_COLLECTED; // total base currency raised (usually ETH)
        uint256 TOTAL_TOKENS_SOLD; // total ilo tokens sold
        uint256 TOTAL_TOKENS_WITHDRAWN; // total tokens withdrawn post successful ilo
        uint256 TOTAL_BASE_WITHDRAWN; // total base tokens withdrawn on ilo failure
        uint256 NUM_BUYERS; // number of unique participants
    }

    struct BuyerInfo {
        uint256 deposited; // deposited base tokens, if ILO fails these can be withdrawn
        uint256 tokensBought; // bought tokens. can be withdrawn on ilo success
    }

    struct FeeInfo {
        address payable FEE_ADDRESS;
        bool PREPAID_FEE;
        uint256 BASE_FEE; // divided by 100
    }
    
    enum ILOState{ 
        QUEUED, 
        ACTIVE, 
        SUCCESS, 
        HARDCAP_MET, 
        FAILED 
    }

    // structs
    ILOInfo public ILO_INFO;
    ILOTimeInfo public ILO_TIME_INFO;
    ILOStatus public STATUS;
    FeeInfo public FEE_INFO;
    // contracts
    ILOSettings public ILO_SETTINGS;
    LiquidityLocker public LIQUIDITY_LOCKER;
    IWBNB WBNB;
    /// @dev reference variable
    address public ILO_FABRIC;
    // addresses
    address public BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    address public TOKEN_LOCK_ADDRESS = 0x0000000000000000000000000000000000000000;
    // BuyerInfo mapping
    mapping(address => BuyerInfo) public BUYERS;


    constructor(address _ILOSettings, address _LiquidityLocker, address _wbnb) {
        ILO_FABRIC = msg.sender;
        ILO_SETTINGS = ILOSettings(_ILOSettings);
        LIQUIDITY_LOCKER = LiquidityLocker(_LiquidityLocker);
        WBNB = IWBNB(_wbnb);
    }

    /// @notice Modifier: Only allow admin address to call certain functions
    modifier onlyAdmin() {
        require(ILO_SETTINGS.isAdmin(msg.sender), "Admin only");
        _;
    }

    /// @notice Modifier: Only allow ILO owner address to call certain functions
    modifier onlyILOOwner() {
        require(msg.sender == ILO_INFO.ILO_OWNER, "ILO owner only");
        _;
    }

    /// @notice Modifier: Only allow ILO owner address to call certain functions
    modifier onlyILOFabric() {
        require(msg.sender == ILO_FABRIC, "ILO_FABRIC only");
        _;
    }

    function initializeILO(
        address payable _iloOwner,
        ERC20 _iloToken,
        ERC20 _baseToken,
        uint256 _tokenPrice, 
        uint256 _amount,
        uint256 _hardcap, 
        uint256 _softcap,
        uint256 _maxSpendPerBuyer,
        uint256 _liquidityPercent,
        // TODO: What is _listingRate vs _tokenPrice?
        uint256 _listingRate
    ) external onlyILOFabric {
        // TODO: Add require statement to verify tokens are not the same or address(0)
        ILO_INFO.ILO_OWNER = _iloOwner;
        ILO_INFO.ILO_TOKEN = _iloToken;
        ILO_INFO.BASE_TOKEN = _baseToken;
        // TODO: Passing WBNB address for BNB ILO? 
        ILO_INFO.ILO_SALE_IN_BNB = address(_baseToken) == address(WBNB) ? true : false;
        // NOTE: Price of token in the base currency? 
        ILO_INFO.TOKEN_PRICE = _tokenPrice;
        // TODO: Amount?
        ILO_INFO.AMOUNT = _amount;
        ILO_INFO.HARDCAP = _hardcap;
        ILO_INFO.SOFTCAP = _softcap;
        ILO_INFO.MAX_SPEND_PER_BUYER = _maxSpendPerBuyer;
        ILO_INFO.LIQUIDITY_PERCENT = _liquidityPercent;
        ILO_INFO.LISTING_PRICE = _listingRate;
    }

    function initializeILO2(
        uint256 _startBlock,
        uint256 _activeBlocks,
        uint256 _lockPeriod,
        bool _prepaidFee,
        bool _burnRemains,
        address payable _feeAddress,
        uint256 _baseFee
    ) external onlyILOFabric {
        ILO_TIME_INFO.START_BLOCK = _startBlock;
        ILO_TIME_INFO.ACTIVE_BLOCKS = _activeBlocks;
        ILO_TIME_INFO.LOCK_PERIOD = _lockPeriod;
        ILO_INFO.BURN_REMAINS = _burnRemains;
        FEE_INFO.PREPAID_FEE = _prepaidFee;
        FEE_INFO.FEE_ADDRESS = _feeAddress;
        FEE_INFO.BASE_FEE = _baseFee;
    }

    function getILOState() public view returns (ILOState) {
        // 5 FAILED - force fail
        if (STATUS.FORCE_FAILED) return ILOState.FAILED; 
        // 4 FAILED - softcap not met by end block
        if ((block.number > ILO_TIME_INFO.START_BLOCK + ILO_TIME_INFO.ACTIVE_BLOCKS) && (STATUS.TOTAL_BASE_COLLECTED < ILO_INFO.SOFTCAP)) return ILOState.FAILED; 
        // 3 SUCCESS - hardcap met
        if (STATUS.TOTAL_BASE_COLLECTED >= ILO_INFO.HARDCAP) return ILOState.HARDCAP_MET; 
        // TODO: Do we need to wait until the liquidity is created?
        // 2 SUCCESS - endblock and soft cap reached
        // TODO: Use a timestamp?
        if ((block.number > ILO_TIME_INFO.START_BLOCK + ILO_TIME_INFO.ACTIVE_BLOCKS) && (STATUS.TOTAL_BASE_COLLECTED >= ILO_INFO.SOFTCAP)) return ILOState.SUCCESS; 
        // 1 ACTIVE - deposits enabled
        if ((block.number >= ILO_TIME_INFO.START_BLOCK) && (block.number <= ILO_TIME_INFO.START_BLOCK + ILO_TIME_INFO.ACTIVE_BLOCKS)) return ILOState.ACTIVE; 
        // 0 QUEUED - awaiting start block
        return ILOState.QUEUED; 
    }

    function userDepositNative () external payable {
        require(ILO_INFO.ILO_SALE_IN_BNB, "not a native token ILO");
        userDepositPrivate(msg.value);
    }

    function userDeposit (uint256 _amount) external {
        require(!ILO_INFO.ILO_SALE_IN_BNB, "cannot deposit tokens in a native token sale");
        userDepositPrivate(_amount);
    }


    // TODO: It is risky to make a function payable when sometimes it takes tokens. Users could send BNB along with their token deposit 
    function userDepositPrivate (uint256 _amount) private {
        require(getILOState() == ILOState.ACTIVE, 'ILO not active');
        BuyerInfo storage buyer = BUYERS[msg.sender];

        uint256 amount_in = ILO_INFO.ILO_SALE_IN_BNB ? msg.value : _amount;
        uint256 allowance = ILO_INFO.MAX_SPEND_PER_BUYER - buyer.deposited;
        uint256 remaining = ILO_INFO.HARDCAP - STATUS.TOTAL_BASE_COLLECTED;
        allowance = allowance > remaining ? remaining : allowance;
        if (amount_in > allowance) {
            amount_in = allowance;
        }

        uint256 tokensSold = amount_in * (10 ** uint256(ILO_INFO.ILO_TOKEN.decimals())) / ILO_INFO.TOKEN_PRICE;
        require(tokensSold > 0, '0 tokens bought');
        if (buyer.deposited == 0) {
            STATUS.NUM_BUYERS++;
        }
        buyer.deposited += amount_in;
        buyer.tokensBought += tokensSold;
        STATUS.TOTAL_BASE_COLLECTED += amount_in;
        STATUS.TOTAL_TOKENS_SOLD += tokensSold;
        
        // return unused BNB
        if (ILO_INFO.ILO_SALE_IN_BNB && amount_in < msg.value) {
            payable(msg.sender).transfer(msg.value - amount_in);
        }
        // deduct non BNB token from user
        if (!ILO_INFO.ILO_SALE_IN_BNB) {
            ILO_INFO.BASE_TOKEN.safeTransferFrom(msg.sender, address(this), amount_in);
        }
    }

    /// @notice The function users call to withdraw funds
    function userWithdraw() external {
        ILOState currentILOState = getILOState();
        // TODO: Combine HARDCAP_MET and SUCCESS?
        require(
            currentILOState == ILOState.SUCCESS || 
            currentILOState == ILOState.HARDCAP_MET || 
            currentILOState == ILOState.FAILED, 
            'Invalid ILO state withdraw'
        );
       
       // TODO: Can user funds be removed?
       // Failed
       if(currentILOState == ILOState.FAILED){ 
           userWithdrawFailedPrivate();
       }
        // Success
       if(currentILOState == ILOState.SUCCESS || currentILOState == ILOState.HARDCAP_MET){ 
           userWithdrawSuccessPrivate();
       }
    }

    function userWithdrawSuccessPrivate() private {
        require(STATUS.LP_GENERATION_COMPLETE, 'Awaiting LP generation');
        BuyerInfo storage buyer = BUYERS[msg.sender];
        require(buyer.tokensBought > 0, 'Nothing to withdraw');
        STATUS.TOTAL_TOKENS_WITHDRAWN += buyer.tokensBought;
        buyer.tokensBought = 0;
        ILO_INFO.ILO_TOKEN.safeTransfer(msg.sender, buyer.tokensBought);
    }

    function userWithdrawFailedPrivate() private {
        BuyerInfo storage buyer = BUYERS[msg.sender];
        require(buyer.deposited > 0, 'Nothing to withdraw');
        STATUS.TOTAL_BASE_WITHDRAWN += buyer.deposited;
        buyer.deposited = 0;
        
        if(ILO_INFO.ILO_SALE_IN_BNB){
            payable(msg.sender).transfer(buyer.deposited);
        } else {
            ILO_INFO.BASE_TOKEN.safeTransfer(msg.sender, buyer.deposited);
        }
    }

    function forceFailAdmin() external onlyAdmin {
        STATUS.FORCE_FAILED = true;
        emit ForceFailed(msg.sender);
    }

    // Change start and end of ILO
    function updateStart(uint256 _startBlock, uint256 _activeBlocks) external onlyILOOwner {
        require(ILO_TIME_INFO.START_BLOCK > block.number, "ILO has already starteds");
        require(_startBlock > block.number, "Start block must be in future");
        require(_activeBlocks >= ILO_SETTINGS.getMinILOLength(), "Active ilo not long enough");
        uint256 previousStartBlock = ILO_TIME_INFO.START_BLOCK;
        ILO_TIME_INFO.START_BLOCK = _startBlock;

        uint256 previousActiveBlocks = ILO_TIME_INFO.ACTIVE_BLOCKS;
        ILO_TIME_INFO.ACTIVE_BLOCKS = _activeBlocks;
        emit UpdateILOBlocks(previousStartBlock, ILO_TIME_INFO.START_BLOCK, previousActiveBlocks, ILO_TIME_INFO.ACTIVE_BLOCKS);
    }

    function updateMaxSpendLimit(uint256 _maxSpend) external onlyILOOwner {
        uint256 previousMaxSpend = ILO_INFO.MAX_SPEND_PER_BUYER;
        ILO_INFO.MAX_SPEND_PER_BUYER = _maxSpend;
        emit UpdateMaxSpendLimit(previousMaxSpend, ILO_INFO.MAX_SPEND_PER_BUYER);
    }

    // TODO: Review function
    //final step when ilo is successfull. lock liquidity and enable withdrawals of sale token.
    function addLiquidity() external {      
        require(!STATUS.LP_GENERATION_COMPLETE, 'GENERATION COMPLETE');
        ILOState currentILOState = getILOState();
        require(currentILOState == ILOState.SUCCESS || currentILOState == ILOState.HARDCAP_MET, 'ILO failed or still in progress'); // SUCCESS

        // FIXME: IF pair is initalized and has tokens in it before it gets here this will short circuit 
        // FIXME: If this is going to be open to the public, we need to evaluate if tokens will get locked in the contract
        // FIXME: If this goes into FORCE_FAILED then the entire ILO won't work 
        if (LIQUIDITY_LOCKER.apePairIsInitialised(address(ILO_INFO.ILO_TOKEN), address(ILO_INFO.BASE_TOKEN))) {
            STATUS.FORCE_FAILED = true;
            return;
        }

        uint256 apeswapBaseFee = FEE_INFO.PREPAID_FEE ? 0 : STATUS.TOTAL_BASE_COLLECTED * FEE_INFO.BASE_FEE / 100;
                
        // base token liquidity
        uint256 baseLiquidity = (STATUS.TOTAL_BASE_COLLECTED - apeswapBaseFee) * ILO_INFO.LIQUIDITY_PERCENT / 100;
        
        // deposit BNB to recieve WBNB tokens
        if (ILO_INFO.ILO_SALE_IN_BNB) {
            WBNB.deposit{value : baseLiquidity}();
        }

        ILO_INFO.BASE_TOKEN.approve(address(LIQUIDITY_LOCKER), baseLiquidity);

        // sale token liquidity
        uint256 saleTokenLiquidity = baseLiquidity * (10 ** ILO_INFO.ILO_TOKEN.decimals()) / ILO_INFO.LISTING_PRICE;
        ILO_INFO.ILO_TOKEN.approve(address(LIQUIDITY_LOCKER), saleTokenLiquidity);

        // TODO: Pass ILO settings address for access control?
        // TODO: Save token lock contract in this contract
        address newTokenLockContract = LIQUIDITY_LOCKER.lockLiquidity(
            ILO_INFO.BASE_TOKEN, 
            ILO_INFO.ILO_TOKEN, 
            baseLiquidity, 
            saleTokenLiquidity, 
            block.timestamp + ILO_TIME_INFO.LOCK_PERIOD, 
            ILO_INFO.ILO_OWNER, 
            ILO_SETTINGS.getAdminAddress()
        );
        TOKEN_LOCK_ADDRESS = newTokenLockContract;

        if(!FEE_INFO.PREPAID_FEE)
        {
            if(ILO_INFO.ILO_SALE_IN_BNB){
                FEE_INFO.FEE_ADDRESS.transfer(apeswapBaseFee);
            } else { 
                ILO_INFO.BASE_TOKEN.transfer(FEE_INFO.FEE_ADDRESS, apeswapBaseFee);
            }
            emit BaseFeeCollected(FEE_INFO.FEE_ADDRESS, apeswapBaseFee);
        }

        // send remaining ilo tokens to ilo owner
        uint256 remainingILOTokenBalance = ILO_INFO.ILO_TOKEN.balanceOf(address(this));
        if (remainingILOTokenBalance > STATUS.TOTAL_TOKENS_SOLD) {
            uint256 amountLeft = remainingILOTokenBalance - STATUS.TOTAL_TOKENS_SOLD;
            if(ILO_INFO.BURN_REMAINS){
                ILO_INFO.ILO_TOKEN.safeTransfer(BURN_ADDRESS, amountLeft);
            } else {
                ILO_INFO.ILO_TOKEN.safeTransfer(ILO_INFO.ILO_OWNER, amountLeft);
            }
        }
        
        // send remaining base tokens to ilo owner
        uint256 remainingBaseBalance = ILO_INFO.ILO_SALE_IN_BNB ? address(this).balance : ILO_INFO.BASE_TOKEN.balanceOf(address(this));
        
        if(ILO_INFO.ILO_SALE_IN_BNB){
            ILO_INFO.ILO_OWNER.transfer(remainingBaseBalance);
        } else {
            ILO_INFO.BASE_TOKEN.safeTransfer(ILO_INFO.ILO_OWNER, remainingBaseBalance);
        }
        
        STATUS.LP_GENERATION_COMPLETE = true;
        emit AddLiquidity(baseLiquidity, saleTokenLiquidity, remainingBaseBalance);
    }
}
