const truffleAssert = require('truffle-assertions');

const ILOFabric = artifacts.require("ILOFabric");
const ILO = artifacts.require("ILO");
const ILOSettings = artifacts.require("ILOSettings");
const ILOExposer = artifacts.require("ILOExposer");
const Banana = artifacts.require("Banana");
const WBNB = artifacts.require("WBNB");
const LiquidityLocker = artifacts.require("LiquidityLocker");

contract("Successful ILO", async (accounts) => {
    let fabric = null;
    let banana = null;
    let wbnb = null;
    let settings = null;
    let exposerAddress = null;
    let exposer = null;
    let locker = null;
    let ilo = null;

    it("Should set all contract variables", async () => {
        fabric = await ILOFabric.deployed();
        banana = await Banana.deployed();
        wbnb = await WBNB.deployed();
        settings = await ILOSettings.deployed();
        locker = await LiquidityLocker.deployed();
        exposerAddress = await fabric.ILO_EXPOSER();
        exposer = await ILOExposer.at(exposerAddress);
    });

    it("Should create and expose new ILO", async () => {
        const FeeAddress = await settings.getFeeAddress();
        const startBalance = await web3.eth.getBalance(FeeAddress);

        const startILOCount = await exposer.ILOsLength();

        await banana.mint("2000000000000000000000000", { from: accounts[1] });
        await banana.approve(fabric.address, "2000000000000000000000000", { from: accounts[1] });
        const blockNumber = await web3.eth.getBlockNumber();
        await fabric.createILO(accounts[1], banana.address, wbnb.address, true, false, ["100000000000000000", "21000000000000000000", "1000000000000000000000", blockNumber + 2, 28700, 60, "2000000000000000000000000", "30", "200000000000000000"], { from: accounts[1], value: 1000000000000000000 })

        //Fee check2
        const newBalance = await web3.eth.getBalance(FeeAddress);

        assert.equal(
            newBalance - startBalance,
            1000000000000000000,
        );

        //new contract exposed check2
        const newILOCount = await exposer.ILOsLength();
        assert.equal(
            newILOCount - startILOCount,
            1,
        );
    });

    it("Should receive the ilo token", async () => {
        const ILOCount = await exposer.ILOsLength();
        const iloAddress = await exposer.ILOAtIndex(ILOCount - 1);
        ilo = await ILO.at(iloAddress);

        const balance = await banana.balanceOf(iloAddress);
        assert.equal(
            balance.valueOf(),
            21000000000000000000 + 3150000000000000000, //hardcoded for now because might change the getTokensRequired() function
            "check for received ilo token"
        );
    });

    it("ilo status should be queued", async () => {
        const iloStatus = await ilo.ILOStatusNumber();
        assert.equal(
            iloStatus,
            0,
            "start status should be 0"
        );
    });

    it("ilo harcap check", async () => {
        status = await ilo.ILO_INFO.call();

        assert.equal(
            status.HARDCAP,
            2100000000000000000,
            "hardcap wrong"
        );
    });

    it("ilo status should be in progress when start block reached", async () => {
        //just anything to increase block number by 1 so the ilo start block is reached
        web3.eth.sendTransaction({ to: accounts[2], from: accounts[0], value: "1000" })

        iloStatus = await ilo.ILOStatusNumber();
        assert.equal(
            iloStatus,
            1,
            "ilo should now be active"
        );
    });

    it("Users should be able to buy ILO tokens", async () => {
        await wbnb.mint("400000000000000000", { from: accounts[2] });
        await wbnb.approve(ilo.address, "400000000000000000", { from: accounts[2] });
        await ilo.userDeposit("400000000000000000", { from: accounts[2] });

        const buyerInfo = await ilo.BUYERS.call(accounts[2]);
        assert.equal(
            buyerInfo.deposited,
            "400000000000000000",
            "account deposited check"
        );
        assert.equal(
            buyerInfo.tokensBought,
            "4000000000000000000",
            "account bought check"
        );
    });

    it("Users should be able to buy limited ILO tokens", async () => {
        await wbnb.mint("10000000000000000", { from: accounts[3] });
        await wbnb.approve(ilo.address, "10000000000000000", { from: accounts[3] });
        await ilo.userDeposit("10000000000000000", { from: accounts[3] });

        const buyerInfo = await ilo.BUYERS.call(accounts[3]);
        assert.equal(
            buyerInfo.deposited,
            "10000000000000000",
            "account deposited check"
        );
        assert.equal(
            buyerInfo.tokensBought,
            "100000000000000000",
            "account bought check"
        );
    });

    it("Users should be able to buy ILO tokens but not more than hardcap", async () => {
        await wbnb.mint("12100000000000000000", { from: accounts[4] });
        await wbnb.approve(ilo.address, "12100000000000000000", { from: accounts[4] });
        await ilo.userDeposit("12100000000000000000", { from: accounts[4] });

        buyerInfo = await ilo.BUYERS.call(accounts[4]);

        assert.equal(
            buyerInfo.deposited,
            "1690000000000000000",
            "account deposited check"
        );
        assert.equal(
            buyerInfo.tokensBought,
            "16900000000000000000",
            "account bought check"
        );
    });

    it("Should change ILO status to success because hardcap reached", async () => {
        iloStatus = await ilo.ILOStatusNumber();
        assert.equal(
            iloStatus,
            3,
            "ilo should now be successfull with hardcap reached"
        );
    });

    let wbnbBalance = null;

    it("Should add liquidity", async () => {
        wbnbBalance = await wbnb.balanceOf(accounts[1]);
        const data = await ilo.addLiquidity();
        status = await ilo.STATUS.call();

        assert.equal(
            status.LP_GENERATION_COMPLETE,
            true,
            "LP generation complete"
        );
    });

    it("Should be able to withdraw bought tokens", async () => {
        const balance = await banana.balanceOf(accounts[2])
        await ilo.userWithdraw({ from: accounts[2] });
        const balanceAfterReceivedTokens = await banana.balanceOf(accounts[2])

        assert.equal(
            balanceAfterReceivedTokens - balance,
            "4000000000000000000",
            "account deposited check"
        );
    });

    it("Should be able to withdraw bought tokens", async () => {
        const balance = await banana.balanceOf(accounts[3])
        await ilo.userWithdraw({ from: accounts[3] });
        const balanceAfterReceivedTokens = await banana.balanceOf(accounts[3])

        assert.equal(
            balanceAfterReceivedTokens - balance,
            "100000000000000000",
            "account deposited check"
        );
    });

    it("Should approve locker to spend base token", async () => {
        const allowance = await wbnb.allowance(ilo.address, locker.address);

        assert.equal(
            allowance,
            "630000000000000000",
            "wrong allowance"
        );
    });

    it("Should approve locker to spend ilo token", async () => {
        const allowance = await banana.allowance(ilo.address, locker.address);

        assert.equal(
            allowance,
            "3150000000000000000",
            "wrong allowance"
        );
    });

    it("transfer base to ilo owner", async () => {
        newWbnbBalance = await wbnb.balanceOf(accounts[1]);

        assert.equal(
            newWbnbBalance - wbnbBalance,
            "1470000000000000000",
            "wrong allowance"
        );
    });

}); 