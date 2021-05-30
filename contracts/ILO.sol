//SPDX-License-Identifier: UNLICENSED
//ALL RIGHTS RESERVED
//apeswap.finance

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./ILOSettings.sol";
//import "./interface/IILOSettings.sol";

contract ILO {
    using SafeERC20 for IERC20;

    struct ILOInfo {
        IERC20 ILO_TOKEN; // token offered for ILO
        IERC20 BASE_TOKEN; // token to buy ILO_TOKEN (if not BNB)
        bool ILO_SALE_IN_BNB; // ILO sale in bnb or BEP20.
        uint256 TOKEN_PRICE; // cost for 1 ILO_TOKEN in BASE_TOKEN (or BNB)
        uint256 AMOUNT; // amount of ILO_TOKENS for sale
        uint256 HARDCAP; // hardcap of earnings.
        uint256 SOFTCAP; // softcap for earning. if not reached ILO is cancelled
        uint256 START_BLOCK; // block to start ILO
        uint256 ACTIVE_BLOCKS; // end of ILO -> START_BLOCK + ACTIVE_BLOCKS
        uint256 LOCK_PERIOD; // unix timestamp (3 weeks) to lock earned tokens for ILO_OWNER
        uint256 MAX_SPEND_PER_BUYER; // max spend per buyer
        address payable ILO_OWNER; //ILO_OWNER address
    }

    struct ILOStatus {
        bool WHITELIST_ONLY; // if set to true only whitelisted members may participate
        bool LP_GENERATION_COMPLETE; // final flag required to end a presale and enable withdrawls
        bool FORCE_FAILED; // set this flag to force fail the presale
        uint256 TOTAL_BASE_COLLECTED; // total base currency raised (usually ETH)
        uint256 TOTAL_TOKENS_SOLD; // total presale tokens sold
        uint256 TOTAL_TOKENS_WITHDRAWN; // total tokens withdrawn post successful presale
        uint256 TOTAL_BASE_WITHDRAWN; // total base tokens withdrawn on presale failure
        uint256 ROUND1_LENGTH; // in blocks
        uint256 NUM_BUYERS; // number of unique participants
    }

    struct BuyerInfo {
        uint256 deposited; // deposited base tokens, if ILO fails these can be withdrawn
        uint256 tokensBought; // bought tokens. can be withdrawn on presale success
    }

    ILOStatus public STATUS;
    ILOInfo public ILO_INFO;
    ILOSettings public ILO_SETTINGS;
    address public ILO_FABRIC;
    mapping(address => BuyerInfo) public BUYERS;

    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);

    address ADMIN_ADDRESS;

    // IPresaleLockForwarder public PRESALE_LOCK_FORWARDER;

    constructor(address _ILOFabric) {
        ILO_FABRIC = _ILOFabric;
        ILO_SETTINGS = ILOSettings(0x539EE706ea34a2145b653C995c4245f41450894d);
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
    IERC20 _iloToken,
    IERC20 _baseToken,
    uint256 _tokenPrice, 
    uint256 _amount,
    uint256 _hardcap, 
    uint256 _softcap,
    uint256 _startBlock,
    uint256 _activeBlocks,
    uint256 _lockPeriod,
    uint256 _maxSpendPerBuyer, 
    address payable _iloOwner
    ) external {
        ILO_INFO.ILO_TOKEN = _iloToken;
        ILO_INFO.BASE_TOKEN = _baseToken;
        ILO_INFO.ILO_SALE_IN_BNB = _baseToken == WBNB ? true : false;
        ILO_INFO.TOKEN_PRICE = _tokenPrice;
        ILO_INFO.AMOUNT = _amount;
        ILO_INFO.HARDCAP = _hardcap;
        ILO_INFO.SOFTCAP = _softcap;
        ILO_INFO.START_BLOCK = _startBlock;
        ILO_INFO.ACTIVE_BLOCKS = _activeBlocks;
        ILO_INFO.LOCK_PERIOD = _lockPeriod;
        ILO_INFO.MAX_SPEND_PER_BUYER = _maxSpendPerBuyer;
        ILO_INFO.ILO_OWNER = _iloOwner;
    }

    function ILOStatusNumber () public view returns (uint256) {
        // 4 FAILED - force fail
        if (STATUS.FORCE_FAILED) return 4; 
        // 4 FAILED - softcap not met by end block
        if ((block.number > ILO_INFO.START_BLOCK + ILO_INFO.ACTIVE_BLOCKS) && (STATUS.TOTAL_BASE_COLLECTED < ILO_INFO.SOFTCAP)) return 4; 
        // 3 SUCCESS - hardcap met
        if (STATUS.TOTAL_BASE_COLLECTED >= ILO_INFO.HARDCAP) return 3; 
        // 2 SUCCESS - endblock and soft cap reached
        if ((block.number > ILO_INFO.START_BLOCK + ILO_INFO.ACTIVE_BLOCKS) && (STATUS.TOTAL_BASE_COLLECTED >= ILO_INFO.SOFTCAP)) return 2; 
        // 1 ACTIVE - deposits enabled
        if ((block.number >= ILO_INFO.START_BLOCK) && (block.number <= ILO_INFO.START_BLOCK + ILO_INFO.ACTIVE_BLOCKS)) return 1; 
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

        uint256 tokensSold = amount_in * ILO_INFO.TOKEN_PRICE / (10 ** uint256(ILO_INFO.BASE_TOKEN.decimals()));
        require(tokensSold > 0, '0 tokens');
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
        buyer.tokensBought = 0;
        ILO_INFO.ILO_TOKEN.transfer(msg.sender, buyer.tokensBought);
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
        require(ILO_INFO.START_BLOCK > block.number);
        require(_startBlock > block.number, "Start block must be in future");
        require(_activeBlocks > 0, "Must be longer than 0 blocks");
        ILO_INFO.START_BLOCK = _startBlock;
        ILO_INFO.ACTIVE_BLOCKS = _activeBlocks;
    }

    function updateMaxSpendLimit(uint256 _maxSpend) external onlyILOOwner {
        ILO_INFO.MAX_SPEND_PER_BUYER = _maxSpend;
    }
}
