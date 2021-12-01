const { balance, expectRevert, time, ether, BN } = require('@openzeppelin/test-helpers');
const { accounts, contract } = require('@openzeppelin/test-environment');
const { expect, assert } = require('chai');
const { getNetworkConfig } = require("../deploy-config");

const ApeFactoryBuild = require('../build-apeswap-dex/contracts/ApeFactory.json');
const ApeFactory = contract.fromABI(ApeFactoryBuild.abi, ApeFactoryBuild.bytecode);
const WNativeBuild = require('../build-apeswap-dex/contracts/WNative.json');
const WNative = contract.fromABI(WNativeBuild.abi, WNativeBuild.bytecode);

// Load compiled artifacts
const ERC20Mock = contract.fromArtifact("ERC20Mock");
// const WNative = contract.fromArtifact("WNative");
const IAZOFactory = contract.fromArtifact("IAZOFactory");
const IAZO = contract.fromArtifact("IAZO");
const IAZOSettings = contract.fromArtifact("IAZOSettings");
const IAZOExposer = contract.fromArtifact("IAZOExposer");
const IAZOUpgradeProxy = contract.fromArtifact("IAZOUpgradeProxy");
const IAZOLiquidityLocker = contract.fromArtifact("IAZOLiquidityLocker");
const IAZOTokenTimelock = contract.fromArtifact("IAZOTokenTimelock");


describe('IAZO native', function () {
    const [minter, proxyAdmin, adminAddress, feeToSetter, feeAddress, alice, bob, carol, dan] = accounts;
    const { wNative } = getNetworkConfig('development', accounts)

    let dexFactory = null;
    let iazoFactory = null;
    let iazoToken = null;
    let wnative = null;
    let settings = null;
    let exposer = null;
    let baseIazo = null;
    let currentIazo = null;
    let liquidityLocker = null;

    it("Should set all contract variables", async () => {
        iazoToken = await ERC20Mock.new();
        wnative = await WNative.new();  
        baseIazo = await IAZO.new();
        exposer = await IAZOExposer.new();
        await exposer.transferOwnership(adminAddress);
        settings = await IAZOSettings.new(adminAddress, feeAddress);
        dexFactory = await ApeFactory.new(feeToSetter);

        this.iazoStartTime = (await settings.getMinStartTime()).toNumber() + 10;
        this.tokenTimelockImplementation = await IAZOTokenTimelock.new();

        const liquidityLockerContract = await IAZOLiquidityLocker.new();
        const liquidityProxy = await IAZOUpgradeProxy.new(proxyAdmin, liquidityLockerContract.address, '0x');
        liquidityLocker = await IAZOLiquidityLocker.at(liquidityProxy.address);
        await liquidityLocker.initialize(
            exposer.address, 
            dexFactory.address, 
            settings.address, 
            adminAddress,
            this.tokenTimelockImplementation.address,
        );

        const factoryContract = await IAZOFactory.new();
        const factoryProxy = await IAZOUpgradeProxy.new(proxyAdmin, factoryContract.address, '0x');
        iazoFactory = await IAZOFactory.at(factoryProxy.address);
        await iazoFactory.initialize(
            exposer.address, 
            settings.address, 
            liquidityLocker.address, 
            baseIazo.address, 
            wnative.address, 
            adminAddress
        );
    });

    it("Should create and expose new IAZO", async () => {
        const FeeAddress = await settings.getFeeAddress();
        const startBalance = await balance.current(FeeAddress, unit = 'wei')

        const startIAZOCount = await exposer.IAZOsLength();

        await iazoToken.mint(ether("2000000"), { from: carol });
        await iazoToken.approve(iazoFactory.address, ether("2000000"), { from: carol });

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
            iazoToken.address, 
            wnative.address, 
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
            ], { from: carol, value: ether('10') })
        currentIazo = await IAZO.at(await exposer.IAZOAtIndex(0));


        //Fee check2
        const newBalance = await balance.current(FeeAddress, unit = 'wei')
        assert.equal(
            newBalance - startBalance,
            '10000000000000000000',
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
        );
        const iazoTokenBalance = await iazoToken.balanceOf(currentIazo.address, {from: carol});
        assert.equal(
            iazoTokenBalance.toString(),
            tokensRequired.toString(),
            'iazo token balance is not accurate'
        )
    });

    it("Should receive the iazo token", async () => {
        const balance = await iazoToken.balanceOf(currentIazo.address);

        /**
         * - 21e18 for sale
         * - 3.15e18 for liquidity (30% of raise at twice the sale price)
         * - 1.05e18 for 5% token fee
         */
        assert.equal(
            balance.valueOf().toString(),
            ether('21').add(ether('3.15')).add(ether('1.05')),
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

    it("iazo hardcap check", async () => {
        status = await currentIazo.IAZO_INFO.call();

        assert.equal(
            status.HARDCAP,
            2100000000000000000,
            "hardcap wrong"
        );
    });

    it("iazo status should be in progress when start time is reached", async () => {
        await time.increaseTo(this.iazoStartTime);


        iazoStatus = await currentIazo.getIAZOState();
        assert.equal(
            iazoStatus.toNumber(),
            1,
            "iazo should now be active"
        );
    });

    it("Should not be able to add liquidity before IAZO is over", async () => {
        await expectRevert(currentIazo.addLiquidity(), "IAZO failed or still in progress");
    });

    it("Users should be able to buy IAZO tokens", async () => {
        await currentIazo.userDepositNative({value: "400000000000000000", from: alice });

        const buyerInfo = await currentIazo.BUYERS.call(alice);
        assert.equal(
            buyerInfo.deposited.toString(),
            "400000000000000000",
            "account deposited check"
        );
        assert.equal(
            buyerInfo.tokensBought.toString(),
            "4000000000000000000",
            "account bought check"
        );
    });

    it("Users should be able to buy IAZO tokens", async () => {
        await currentIazo.userDepositNative({value: "10000000000000000", from: bob });

        const buyerInfo = await currentIazo.BUYERS.call(bob);
        assert.equal(
            buyerInfo.deposited.toString(),
            "10000000000000000",
            "account deposited check"
        );
        assert.equal(
            buyerInfo.tokensBought.toString(),
            "100000000000000000",
            "account bought check"
        );
    });

    it("Users should be able to buy IAZO tokens but not more than hardcap", async () => {
        await currentIazo.userDepositNative({value: "12100000000000000000", from: dan });

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
            "iazo should now be successful with hardcap reached"
        );
    });


    let baseTokenBalance = null;
    let IAZOTokenBalance = null;
    let feeBaseTokenBalance = null;
    let feeIAZOTokenBalance = null;

    it("Should add liquidity and be able to withdraw bought tokens", async () => {
        baseTokenBalance= await balance.current(carol, unit = 'wei');
        IAZOTokenBalance= await iazoToken.balanceOf(carol);
        feeBaseTokenBalance= await balance.current(feeAddress, unit = 'wei');
        feeIAZOTokenBalance= await iazoToken.balanceOf(feeAddress);

        // NOTE: Can call this function publicly after the IAZO, but testing withdraw
        // await currentIazo.addLiquidity();
        await currentIazo.userWithdraw({ from: alice });
        const balanceAfterReceivedTokens = await iazoToken.balanceOf(alice)

        // Test LP generation on initial withdraw 
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
        const balance = await iazoToken.balanceOf(bob)
        await currentIazo.userWithdraw({ from: bob });
        const balanceAfterReceivedTokens = await iazoToken.balanceOf(bob)

        assert.equal(
            balanceAfterReceivedTokens - balance,
            "100000000000000000",
            "account deposited check"
        );
    });

    it("transfer base to iazo owner", async () => {
        newWnativeBalance = await balance.current(carol, unit = 'wei');

        assert.equal(
            newWnativeBalance - baseTokenBalance,
            //2.1 - 5% fee - 30% liquidity
            new BN("1365000000000000000"),
            "wrong balance"
        );
    });

    it("transfer left over iazo tokens to iazo owner", async () => {
        newIAZOTokenBalance = await iazoToken.balanceOf(carol);

        assert.equal(
            newIAZOTokenBalance - IAZOTokenBalance,
            //All iazo tokens should be sold (or used for liquidity and fees)
            new BN("0"),
            "wrong balance"
        );
    });

    it("transfer fees to fee address", async () => {
        newBaseTokenBalance = await balance.current(feeAddress, unit = 'wei');
        newIAZOTokenBalance = await iazoToken.balanceOf(feeAddress);

        assert.equal(
            newBaseTokenBalance - feeBaseTokenBalance,
            // Default base token fee is 5%
            new BN("2100000000000000000").div(new BN('20')),
            "wrong balance"
        );

        assert.equal(
            newIAZOTokenBalance - feeIAZOTokenBalance,
            // Default iazo token fee is 5%
            new BN("21000000000000000000").div(new BN('20')),
            "wrong balance"
        );
    });
});