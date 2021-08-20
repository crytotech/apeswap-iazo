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
    const [minter, proxyAdmin, adminAddress, feeToSetter, feeAddress, alice, bob, carol, dan] = accounts;
    // TODO: Need a mock wNative token
    const { wNative } = getNetworkConfig('development', accounts)

    let dexFactory = null;
    let iazoFactory = null;
    let banana = null;
    let wnative = null;
    let settings = null;
    let exposer = null;
    let baseIazo = null;
    let currentIazo = null;
    let liquidityLocker = null;

    it("Should set all contract variables", async () => {
        banana = await WNativeMock.new();
        wnative = await WNativeMock.new();  
        baseIazo = await IAZO.new();
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
            baseIazo.address, 
            wNative, 
            adminAddress
        );
    });

    it("Should create and expose new IAZO", async () => {
        const FeeAddress = await settings.getFeeAddress();
        const startBalance = await balance.current(FeeAddress, unit = 'wei')

        const startIAZOCount = await exposer.IAZOsLength();

        await banana.mint(ether("2000000"), { from: carol });
        await banana.approve(iazoFactory.address, ether("2000000"), { from: carol });

        let IAZOConfig = {
            tokenPrice: ether('.1'), // token price
            amount: ether('21'), // amount
            softcap: ether('1'), // softcap in base tokens
            startTime: this.iazoStartTime, // start time
            activeTime: 43201, // active time
            lockPeriod: 2419000, // lock period
            maxSpendPerBuyer: ether("2000000"), // max spend per buyer
            liquidityPercent: "300", // liquidity percent
            listingPrice: ether(".2") // listing price
        }
        await iazoFactory.createIAZO(
            carol, 
            banana.address, 
            wnative.address, 
            true, 
            false, 
            [
                IAZOConfig.tokenPrice,
                IAZOConfig.amount,
                IAZOConfig.softcap,
                IAZOConfig.startTime,
                IAZOConfig.activeTime,
                IAZOConfig.lockPeriod,
                IAZOConfig.maxSpendPerBuyer,
                IAZOConfig.liquidityPercent,
                IAZOConfig.listingPrice,
            ], { from: carol, value: ether('1') })
        currentIazo = await IAZO.at(await exposer.IAZOAtIndex(0));


        //Fee check2
        const newBalance = await balance.current(FeeAddress, unit = 'wei')
        assert.equal(
            newBalance - startBalance,
            '1000000000000000000',
        );

        //new contract exposed check2
        const newIAZOCount = await exposer.IAZOsLength();
        assert.equal(
            newIAZOCount - startIAZOCount,
            1,
        );

        const tokensRequired = await iazoFactory.getTokensRequired(
            IAZOConfig.amount, 
            IAZOConfig.tokenPrice, 
            IAZOConfig.listingPrice, 
            IAZOConfig.liquidityPercent,
            18 // decimals
        );
        const iazoTokenBalance = await banana.balanceOf(currentIazo.address, {from: carol});
        assert.equal(
            iazoTokenBalance.toString(),
            tokensRequired.toString(),
            'iazo token balance is not accurate'
        )
    });

    it("Should receive the iazo token", async () => {
        const balance = await banana.balanceOf(currentIazo.address);
        assert.equal(
            balance.valueOf(),
            21000000000000000000 + 3150000000000000000, //hardcoded for now because might change the getTokensRequired() function
            "check for received iazo token"
        );
    });

    it("iazo status should be queued", async () => {
        const iazoStatus = await currentIazo.getIAZOState();
        assert.equal(
            iazoStatus,
            0,
            "start status should be 0"
        );
    });

    it("iazo harcap check", async () => {
        status = await currentIazo.IAZO_INFO.call();

        assert.equal(
            status.HARDCAP,
            2100000000000000000,
            "hardcap wrong"
        );
    });

    it("iazo status should be in progress when start time is reached", async () => {
        time.increaseTo(this.iazoStartTime);


        iazoStatus = await currentIazo.getIAZOState();
        assert.equal(
            iazoStatus,
            1,
            "iazo should now be active"
        );
    });

    it("Users should be able to buy IAZO tokens", async () => {
        await wnative.mint("400000000000000000", { from: alice });
        await wnative.approve(currentIazo.address, "400000000000000000", { from: alice });
        await currentIazo.userDeposit("400000000000000000", { from: alice });

        const buyerInfo = await currentIazo.BUYERS.call(alice);
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
        await wnative.mint("10000000000000000", { from: bob });
        await wnative.approve(currentIazo.address, "10000000000000000", { from: bob });
        await currentIazo.userDeposit("10000000000000000", { from: bob });

        const buyerInfo = await currentIazo.BUYERS.call(bob);
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
        await wnative.mint("12100000000000000000", { from: dan });
        await wnative.approve(currentIazo.address, "12100000000000000000", { from: dan });
        await currentIazo.userDeposit("12100000000000000000", { from: dan });

        buyerInfo = await currentIazo.BUYERS.call(dan);

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
        iazoStatus = await currentIazo.getIAZOState();
        assert.equal(
            iazoStatus,
            3,
            "iazo should now be successfull with hardcap reached"
        );
    });


    let wnativeBalance = null;

    it("Should add liquidity", async () => {
        wnativeBalance = await wnative.balanceOf(carol);
        await currentIazo.addLiquidity();
        status = await currentIazo.STATUS.call();
        
        assert.equal(
            status.LP_GENERATION_COMPLETE,
            true,
            "LP generation complete"
        );
        assert.equal(
            status.FORCE_FAILED,
            false,
            "force failed invalid"
        );
    });

    it("Should be able to withdraw bought tokens", async () => {
        await currentIazo.userWithdraw({ from: alice });
        const balanceAfterReceivedTokens = await banana.balanceOf(alice)


        const buyerInfo = await currentIazo.BUYERS.call(alice);
        assert.equal(
            buyerInfo.deposited,
            "400000000000000000",
            "account deposited check"
        );
        assert.equal(
            buyerInfo.tokensBought,
            "0",
            "account bought check"
        );

        assert.equal(
            balanceAfterReceivedTokens.toString(),
            "4000000000000000000",
            "account deposited check"
        );
    });

    it("Should be able to withdraw bought tokens", async () => {
        const balance = await banana.balanceOf(bob)
        await currentIazo.userWithdraw({ from: bob });
        const balanceAfterReceivedTokens = await banana.balanceOf(bob)

        assert.equal(
            balanceAfterReceivedTokens - balance,
            "100000000000000000",
            "account deposited check"
        );
    });

    it("Should approve locker to spend base token", async () => {
        const allowance = await wnative.allowance(currentIazo.address, liquidityLocker.address);

        assert.equal(
            allowance,
            "630000000000000000",
            "wrong allowance"
        );
    });

    it("Should approve locker to spend iazo token", async () => {
        const allowance = await banana.allowance(currentIazo.address, liquidityLocker.address);

        assert.equal(
            allowance,
            "3150000000000000000",
            "wrong allowance"
        );
    });

    it("transfer base to iazo owner", async () => {
        newWnativeBalance = await wnative.balanceOf(carol);

        assert.equal(
            newWnativeBalance - wnativeBalance,
            "1470000000000000000",
            "wrong balance"
        );
    });
});