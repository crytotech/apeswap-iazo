//SPDX-License-Identifier: UNLICENSED
//ALL RIGHTS RESERVED
//apeswap.finance

pragma solidity ^0.8.4;

import "./interface/ERC20.sol";
import "./interface/IWBNB.sol";
import "./ILOSettings.sol";
import "./LiquidityLocker.sol";
//import "./interface/IILOSettings.sol";

contract ILO {
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
        uint256 LISTING_RATE; // fixed rate at which the token will list on apeswap
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
        uint256 BASE_FEE; // divided by 1000
        uint256 TOKEN_FEE; // divided by 1000
    }

    ILOStatus public STATUS;
    ILOInfo public ILO_INFO;
    ILOTimeInfo public ILO_TIME_INFO;
    ILOSettings public ILO_SETTINGS;
    LiquidityLocker public LIQUIDITY_LOCKER;
    FeeInfo public FEE_INFO;
    address public ILO_FABRIC;
    mapping(address => BuyerInfo) public BUYERS;

    IWBNB WBNB = IWBNB(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);

    address ADMIN_ADDRESS;
    address payable FEE_ADDRESS;

    constructor(address _ILOFabric) {
        ILO_FABRIC = _ILOFabric;
        ILO_SETTINGS = ILOSettings(0x94b83042B48F239c9CcF1537471334D474E11037);
        LIQUIDITY_LOCKER = LiquidityLocker(0x6a326e0E1a28840DBdf61dbBE01B2A218C15d969);
        ADMIN_ADDRESS = 0x539EE706ea34a2145b653C995c4245f41450894d;
    }

    //Modifier: Only allow admin address to call certain functions
    modifier onlyAdmin() {
        require(msg.sender == ADMIN_ADDRESS, "Admin only");
        _;
    }

    //Modifier: Only allow ILO owner address to call certain functions
    modifier onlyILOOwner() {
        require(msg.sender == ILO_INFO.ILO_OWNER, "ILO owner only");
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
        uint256 _listingRate
    ) external {
        ILO_INFO.ILO_OWNER = _iloOwner;
        ILO_INFO.ILO_TOKEN = _iloToken;
        ILO_INFO.BASE_TOKEN = _baseToken;
        ILO_INFO.ILO_SALE_IN_BNB = address(_baseToken) == address(WBNB) ? true : false;
        ILO_INFO.TOKEN_PRICE = _tokenPrice;
        ILO_INFO.AMOUNT = _amount;
        ILO_INFO.HARDCAP = _hardcap;
        ILO_INFO.SOFTCAP = _softcap;
        ILO_INFO.MAX_SPEND_PER_BUYER = _maxSpendPerBuyer;
        ILO_INFO.LIQUIDITY_PERCENT = _liquidityPercent;
        ILO_INFO.LISTING_RATE = _listingRate;
    }

    function initializeILO2(
        uint256 _startBlock,
        uint256 _activeBlocks,
        uint256 _lockPeriod,
        address payable _feeAddress,
        uint256 _baseFee,
        uint256 _tokenFee
    ) external {
        ILO_TIME_INFO.START_BLOCK = _startBlock;
        ILO_TIME_INFO.ACTIVE_BLOCKS = _activeBlocks;
        ILO_TIME_INFO.LOCK_PERIOD = _lockPeriod;

        FEE_INFO.FEE_ADDRESS = _feeAddress;
        FEE_INFO.BASE_FEE = _baseFee;
        FEE_INFO.TOKEN_FEE = _tokenFee;
    }

    function ILOStatusNumber () public view returns (uint256) {
        // 4 FAILED - force fail
        if (STATUS.FORCE_FAILED) return 4; 
        // 4 FAILED - softcap not met by end block
        if ((block.number > ILO_TIME_INFO.START_BLOCK + ILO_TIME_INFO.ACTIVE_BLOCKS) && (STATUS.TOTAL_BASE_COLLECTED < ILO_INFO.SOFTCAP)) return 4; 
        // 3 SUCCESS - hardcap met
        if (STATUS.TOTAL_BASE_COLLECTED >= ILO_INFO.HARDCAP) return 3; 
        // 2 SUCCESS - endblock and soft cap reached
        if ((block.number > ILO_TIME_INFO.START_BLOCK + ILO_TIME_INFO.ACTIVE_BLOCKS) && (STATUS.TOTAL_BASE_COLLECTED >= ILO_INFO.SOFTCAP)) return 2; 
        // 1 ACTIVE - deposits enabled
        if ((block.number >= ILO_TIME_INFO.START_BLOCK) && (block.number <= ILO_TIME_INFO.START_BLOCK + ILO_TIME_INFO.ACTIVE_BLOCKS)) return 1; 
        // 0 QUEUED - awaiting start block
        return 0; 
    }

    function userDeposit (uint256 _amount) external payable {
        require(ILOStatusNumber() == 1, 'Not active');
        BuyerInfo storage buyer = BUYERS[msg.sender];

        uint256 amount_in = ILO_INFO.ILO_SALE_IN_BNB ? msg.value : _amount;
        uint256 allowance = ILO_INFO.MAX_SPEND_PER_BUYER - buyer.deposited;
        uint256 remaining = ILO_INFO.HARDCAP - STATUS.TOTAL_BASE_COLLECTED;
        allowance = allowance > remaining ? remaining : allowance;
        if (amount_in > allowance) {
            amount_in = allowance;
        }

        uint256 tokensSold = amount_in / ILO_INFO.TOKEN_PRICE * (10 ** uint256(ILO_INFO.BASE_TOKEN.decimals()));
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
            ILO_INFO.BASE_TOKEN.transferFrom(msg.sender, address(this), amount_in);
        }
    }

    function userWithdraw() external {
       uint256 ILOstatus = ILOStatusNumber();
       
       // Failed
       if(ILOstatus == 4){ 
           userWithdrawFailed();
       }
        // Success
       if(ILOstatus == 2 || ILOstatus == 3){ 
           userWithdrawSuccess();
       }
    }

    function userWithdrawSuccess() private {
        require(STATUS.LP_GENERATION_COMPLETE, 'Awaiting LP generation');
        BuyerInfo storage buyer = BUYERS[msg.sender];
        require(buyer.tokensBought > 0, 'Nothing to withdraw');
        STATUS.TOTAL_TOKENS_WITHDRAWN += buyer.tokensBought;
        ILO_INFO.ILO_TOKEN.transfer(msg.sender, buyer.tokensBought);
        buyer.tokensBought = 0;
    }

    function userWithdrawFailed() private {
        BuyerInfo storage buyer = BUYERS[msg.sender];
        require(buyer.deposited > 0, 'Nothing to withdraw');
        STATUS.TOTAL_BASE_WITHDRAWN += buyer.deposited;
        buyer.deposited = 0;
        
        if(ILO_INFO.ILO_SALE_IN_BNB){
            payable(msg.sender).transfer(buyer.deposited);
        } else {
            ILO_INFO.BASE_TOKEN.transfer(msg.sender, buyer.deposited);
        }
    }

    function forceFailAdmin() external onlyAdmin {
        STATUS.FORCE_FAILED = true;
    }

    // Change start and end of ILO
    function updateStart(uint256 _startBlock, uint256 _activeBlocks) external onlyILOOwner {
        require(ILO_TIME_INFO.START_BLOCK > block.number, "Current ilo start block not in future");
        require(_startBlock > block.number, "Start block must be in future");
        require(_activeBlocks >= ILO_SETTINGS.getMinILOLength(), "Active ilo not long enough");
        ILO_TIME_INFO.START_BLOCK = _startBlock;
        ILO_TIME_INFO.ACTIVE_BLOCKS = _activeBlocks;
    }

    function updateMaxSpendLimit(uint256 _maxSpend) external onlyILOOwner {
        ILO_INFO.MAX_SPEND_PER_BUYER = _maxSpend;
    }

    //final step when ilo is successfull. lock liquidity and enable withdrawals of sale token.
    function addLiquidity() external {
        STATUS.LP_GENERATION_COMPLETE = true;
        
        // require(!STATUS.LP_GENERATION_COMPLETE, 'GENERATION COMPLETE');
        // require(ILOStatusNumber() == 2 || ILOStatusNumber() == 3, 'ILO failed or still in progress'); // SUCCESS

        // if (LIQUIDITY_LOCKER.uniswapPairIsInitialised(address(ILO_INFO.ILO_TOKEN), address(ILO_INFO.BASE_TOKEN))) {
        //     STATUS.FORCE_FAILED = true;
        //     return;
        // }
        
        // uint256 apeswapBaseFee = STATUS.TOTAL_BASE_COLLECTED * FEE_INFO.BASE_FEE / 1000;
        
        // // base token liquidity
        // uint256 baseLiquidity = STATUS.TOTAL_BASE_COLLECTED - apeswapBaseFee * ILO_INFO.LIQUIDITY_PERCENT / 1000;
        
        // if (ILO_INFO.ILO_SALE_IN_BNB) {
        //     WBNB.deposit{value : baseLiquidity}();
        // }

        // ILO_INFO.BASE_TOKEN.approve(address(LIQUIDITY_LOCKER), baseLiquidity);

        // // sale token liquidity
        // uint256 tokenLiquidity = baseLiquidity * ILO_INFO.LISTING_RATE / 10 ** uint256(ILO_INFO.BASE_TOKEN.decimals());
        // ILO_INFO.ILO_TOKEN.approve(address(LIQUIDITY_LOCKER), tokenLiquidity);

        // LIQUIDITY_LOCKER.lockLiquidity(ILO_INFO.BASE_TOKEN, ILO_INFO.ILO_TOKEN, baseLiquidity, tokenLiquidity, block.timestamp + ILO_TIME_INFO.LOCK_PERIOD, ILO_INFO.ILO_OWNER);
        
        // // transfer fees
        // uint256 apeswapTokenFee = STATUS.TOTAL_TOKENS_SOLD * FEE_INFO.TOKEN_FEE / 1000;

        // if(ILO_INFO.ILO_SALE_IN_BNB){
        //     FEE_INFO.FEE_ADDRESS.transfer(apeswapBaseFee);
        // } else {
        //     ILO_INFO.BASE_TOKEN.transfer(FEE_INFO.FEE_ADDRESS, apeswapTokenFee);
        // }
        // ILO_INFO.ILO_TOKEN.transfer(FEE_INFO.FEE_ADDRESS, apeswapTokenFee);
        
        // // send remaining ilo tokens to ilo owner
        // uint256 remainingILOTokenBalance = ILO_INFO.ILO_TOKEN.balanceOf(address(this));
        // if (remainingILOTokenBalance > STATUS.TOTAL_TOKENS_SOLD) {
        //     uint256 amountLeft = remainingILOTokenBalance - STATUS.TOTAL_TOKENS_SOLD;
        //     ILO_INFO.ILO_TOKEN.transfer(ILO_INFO.ILO_OWNER, amountLeft);
        // }
        
        // // send remaining base tokens to ilo owner
        // uint256 remainingBaseBalance = ILO_INFO.ILO_SALE_IN_BNB ? address(this).balance : ILO_INFO.BASE_TOKEN.balanceOf(address(this));
        
        // if(ILO_INFO.ILO_SALE_IN_BNB){
        //     FEE_INFO.FEE_ADDRESS.transfer(remainingBaseBalance);
        // } else {
        //     ILO_INFO.BASE_TOKEN.transfer(ILO_INFO.ILO_OWNER, remainingBaseBalance);
        // }
        
        // STATUS.LP_GENERATION_COMPLETE = true;
    }
}
