const { balance, expectRevert, time, ether } = require('@openzeppelin/test-helpers');
const { accounts, contract } = require('@openzeppelin/test-environment');
const { expect, assert } = require('chai');
const { getNetworkConfig } = require("../deploy-config");

const ApeFactoryBuild = require('../build-apeswap-dex/contracts/ApeFactory.json');
const ApeFactory = contract.fromABI(ApeFactoryBuild.abi, ApeFactoryBuild.bytecode);

// Load compiled artifacts
const WNativeMock = contract.fromArtifact("WNativeMock");
const IAZOFactory = contract.fromArtifact("IAZOFactory");
const IAZO = contract.fromArtifact("IAZO");
const IAZOSettings = contract.fromArtifact("IAZOSettings");
const IAZOExposer = contract.fromArtifact("IAZOExposer");
const IAZOUpgradeProxy = contract.fromArtifact("IAZOUpgradeProxy");
const IAZOLiquidityLocker = contract.fromArtifact("IAZOLiquidityLocker");


describe('IAZO', function () {
    const [proxyAdmin, adminAddress, feeToSetter] = accounts;
    const { feeAddress, wNative } = getNetworkConfig('development', accounts);

    let dexFactory = null;
    let iazoFactory = null;
    let banana = null;
    let wnative = null;
    let settings = null;
    let exposer = null;
    let iazo = null;
    let liquidityLocker = null;

    it("Should set all contract variables", async () => {
        banana = await WNativeMock.new();
        wnative = await WNativeMock.new();  
        iazo = await IAZO.new();
        exposer = await IAZOExposer.new();
        await exposer.transferOwnership(adminAddress);
        settings = await IAZOSettings.new(adminAddress, feeAddress);
        dexFactory = await ApeFactory.new(feeToSetter);

        this.iazoStartTime = (await time.latest()) + 10;

        const liquidityLockerContract = await IAZOLiquidityLocker.new();
        const liquidityProxy = await IAZOUpgradeProxy.new(proxyAdmin, liquidityLockerContract.address, '0x');
        liquidityLocker = await IAZOLiquidityLocker.at(liquidityProxy.address);
        await liquidityLocker.initialize(
            exposer.address, 
            dexFactory.address, 
            settings.address, 
            adminAddress
        );

        const factoryContract = await IAZOFactory.new();
        const factoryProxy = await IAZOUpgradeProxy.new(proxyAdmin, factoryContract.address, '0x');
        iazoFactory = await IAZOFactory.at(factoryProxy.address);
        await iazoFactory.initialize(
            exposer.address, 
            settings.address, 
            liquidityLocker.address, 
            iazo.address, 
            wNative, 
            adminAddress
        );
    });

    it("Should create and expose new IAZO", async () => {
        const FeeAddress = await settings.getFeeAddress();
        const startBalance = await balance.current(FeeAddress, unit = 'wei')

        const startIAZOCount = await exposer.IAZOsLength();

        await banana.mint("2000000000000000000000000", { from: accounts[1] });
        await banana.approve(iazoFactory.address, "2000000000000000000000000", { from: accounts[1] });
        await iazoFactory.createIAZO(
            accounts[1], 
            banana.address, 
            wnative.address, 
            true, 
            false, 
            [
                "100000000000000000", // token price
                "21000000000000000000", // amount
                "1000000000000000000", // softcap
                this.iazoStartTime, // start time
                43201, // active time
                2419000, // lock period
                "2000000000000000000000000", // max spend per buyer
                "30", // liquidity percent
                "200000000000000000" // listing price
            ], { from: accounts[1], value: 1000000000000000000 })

        //Fee check2
        const newBalance = await balance.current(FeeAddress, unit = 'wei')

        assert.equal(
            newBalance - startBalance,
            1000000000000000000,
        );

        //new contract exposed check2
        const newIAZOCount = await exposer.IAZOsLength();
        assert.equal(
            newIAZOCount - startIAZOCount,
            1,
        );
    });

    it("Should receive the iazo token", async () => {
        const IAZOCount = await exposer.IAZOsLength();
        const iazoAddress = await exposer.IAZOAtIndex(IAZOCount - 1);
        iazo = await IAZO.at(iazoAddress);

        const balance = await banana.balanceOf(iazoAddress);
        assert.equal(
            balance.valueOf(),
            21000000000000000000 + 3150000000000000000, //hardcoded for now because might change the getTokensRequired() function
            "check for received iazo token"
        );
    });

    it("iazo status should be queued", async () => {
        const iazoStatus = await iazo.getIAZOState();
        assert.equal(
            iazoStatus,
            0,
            "start status should be 0"
        );
    });

    it("iazo harcap check", async () => {
        status = await iazo.IAZO_INFO.call();

        assert.equal(
            status.HARDCAP,
            2100000000000000000,
            "hardcap wrong"
        );
    });

    it("iazo status should be in progress when start time is reached", async () => {
        time.increaseTo(this.iazoStartTime);


        iazoStatus = await iazo.getIAZOState();
        assert.equal(
            iazoStatus,
            1,
            "iazo should now be active"
        );
    });

    it("Users should be able to buy IAZO tokens", async () => {
        await wnative.mint("400000000000000000", { from: accounts[2] });
        await wnative.approve(iazo.address, "400000000000000000", { from: accounts[2] });
        await iazo.userDeposit("400000000000000000", { from: accounts[2] });

        const buyerInfo = await iazo.BUYERS.call(accounts[2]);
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

    it("Users should be able to buy limited IAZO tokens", async () => {
        await wnative.mint("10000000000000000", { from: accounts[3] });
        await wnative.approve(iazo.address, "10000000000000000", { from: accounts[3] });
        await iazo.userDeposit("10000000000000000", { from: accounts[3] });

        const buyerInfo = await iazo.BUYERS.call(accounts[3]);
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

    it("Users should be able to buy IAZO tokens but not more than hardcap", async () => {
        await wnative.mint("12100000000000000000", { from: accounts[4] });
        await wnative.approve(iazo.address, "12100000000000000000", { from: accounts[4] });
        await iazo.userDeposit("12100000000000000000", { from: accounts[4] });

        buyerInfo = await iazo.BUYERS.call(accounts[4]);

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

    it("Should change IAZO status to success because hardcap reached", async () => {
        iazoStatus = await iazo.getIAZOState();
        assert.equal(
            iazoStatus,
            3,
            "iazo should now be successfull with hardcap reached"
        );
    });

    let wnativeBalance = null;

    it("Should add liquidity", async () => {
        wnativeBalance = await wnative.balanceOf(accounts[1]);
        const data = await iazo.addLiquidity();
        status = await iazo.STATUS.call();

        assert.equal(
            status.LP_GENERATION_COMPLETE,
            true,
            "LP generation complete"
        );
    });

    it("Should be able to withdraw bought tokens", async () => {
        const balance = await banana.balanceOf(accounts[2])
        await iazo.userWithdraw({ from: accounts[2] });
        const balanceAfterReceivedTokens = await banana.balanceOf(accounts[2])

        assert.equal(
            balanceAfterReceivedTokens - balance,
            "4000000000000000000",
            "account deposited check"
        );
    });

    it("Should be able to withdraw bought tokens", async () => {
        const balance = await banana.balanceOf(accounts[3])
        await iazo.userWithdraw({ from: accounts[3] });
        const balanceAfterReceivedTokens = await banana.balanceOf(accounts[3])

        assert.equal(
            balanceAfterReceivedTokens - balance,
            "100000000000000000",
            "account deposited check"
        );
    });

    it("Should approve locker to spend base token", async () => {
        const allowance = await wnative.allowance(iazo.address, liquidityLocker.address);

        assert.equal(
            allowance,
            "630000000000000000",
            "wrong allowance"
        );
    });

    it("Should approve locker to spend iazo token", async () => {
        const allowance = await banana.allowance(iazo.address, liquidityLocker.address);

        assert.equal(
            allowance,
            "3150000000000000000",
            "wrong allowance"
        );
    });

    it("transfer base to iazo owner", async () => {
        newWnativeBalance = await wnative.balanceOf(accounts[1]);

        assert.equal(
            newWnativeBalance - wnativeBalance,
            "1470000000000000000",
            "wrong allowance"
        );
    });
});