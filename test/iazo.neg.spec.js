const { balance, expectRevert, time, ether } = require('@openzeppelin/test-helpers');
const { accounts, contract } = require('@openzeppelin/test-environment');
const { expect, assert } = require('chai');
const { getNetworkConfig } = require("../deploy-config");

// Load compiled artifacts
const IAZOFactory = contract.fromArtifact("IAZOFactory");
const IAZO = contract.fromArtifact("IAZO");
const IAZOSettings = contract.fromArtifact("IAZOSettings");
const IAZOExposer = contract.fromArtifact("IAZOExposer");
const ERC20Mock = contract.fromArtifact("ERC20Mock");
const IAZOUpgradeProxy = contract.fromArtifact("IAZOUpgradeProxy");
const IAZOLiquidityLocker = contract.fromArtifact("IAZOLiquidityLocker");
const IAZOTokenTimelock = contract.fromArtifact("IAZOTokenTimelock");


describe("IAZO - Negative Tests", async function() {
    const [proxyAdmin, adminAddress, alice, bob] = accounts;
    const { feeAddress, wNative, apeFactory } = getNetworkConfig('development', accounts);

    let factory = null;
    let banana = null;
    let baseToken = null;
    let settings = null;
    let exposer = null;
    let iazo = null;
    let liquidity = null;
    let tokenTimelock = null;

    let startTimestamp = null;

    it("Should set all contract variables", async () => {
        banana = await ERC20Mock.new();
        baseToken = await ERC20Mock.new();
        iazo = await IAZO.new();
        exposer = await IAZOExposer.new();
        await exposer.transferOwnership(adminAddress);
        settings = await IAZOSettings.new(adminAddress, feeAddress);
        tokenTimelock = await IAZOTokenTimelock.new();

        const liquidityLockerContract = await IAZOLiquidityLocker.new();
        const liquidityProxy = await IAZOUpgradeProxy.new(proxyAdmin, liquidityLockerContract.address, '0x');
        liquidity = await IAZOLiquidityLocker.at(liquidityProxy.address);
        await liquidity.initialize(exposer.address, apeFactory, settings.address, adminAddress, tokenTimelock.address);

        IAZOFactory.defaults({
            gasPrice: 0,
        })
        IAZOUpgradeProxy.defaults({
            gasPrice: 0,
        })
        const factoryContract = await IAZOFactory.new();
        const factoryProxy = await IAZOUpgradeProxy.new(proxyAdmin, factoryContract.address, '0x');
        factory = await IAZOFactory.at(factoryProxy.address);
        factory.initialize(exposer.address, settings.address, liquidity.address, iazo.address, wNative, adminAddress);
    });

    it("Should create and expose new IAZO", async () => {
        const FeeAddress = await settings.getFeeAddress();
        const startBalance = await balance.current(FeeAddress, unit = 'wei')

        const startIAZOCount = await exposer.IAZOsLength();

        const iazoDetails = {
            tokenPrice: '2000000000000000000',
            amount: '1000000000000000000000000',
            softCap: '1000000000000000000000',
            listingPrice: '2000000000000000000',
            liquidityPercent: '300',
        }

        const tokensRequired = await factory.getTokensRequired(
            iazoDetails.amount,
            iazoDetails.tokenPrice,
            iazoDetails.listingPrice,
            iazoDetails.liquidityPercent,
        )

        // 5% of offer tokens + liquidity + sale tokens
        assert.equal(
            tokensRequired.toString(),
            '1350000000000000000000000',
            'IAZO get tokens required is not accurate'
        );

        await banana.mint(tokensRequired, { from: alice });
        await banana.approve(factory.address, tokensRequired, { from: alice });
        startTimestamp = (await settings.getMinStartTime()).toNumber() + 10;
        await factory.createIAZO(
            alice, 
            banana.address, 
            baseToken.address, 
            false, 
            [
                iazoDetails.tokenPrice, // token price
                iazoDetails.amount, // amount
                iazoDetails.softCap, // softcap
                startTimestamp, // start time
                43201, // active time
                2419000, // lock period
                "2000000000000000000000000", // max spend per buyer
                iazoDetails.liquidityPercent, // liquidity percent
                iazoDetails.softCap // listing price
            ], { from: alice, value: 10000000000000000000 })

        //Fee check2
        const newBalance = await balance.current(FeeAddress, unit = 'wei')

        assert.equal(
            newBalance - startBalance,
            10000000000000000000,
        );

        //new contract exposed check2
        const newIAZOCount = await exposer.IAZOsLength();
        assert.equal(
            newIAZOCount - startIAZOCount,
            1,
        );
    });

    it("iazo status should be queued", async () => {
        const IAZOCount = await exposer.IAZOsLength();
        const iazoAddress = await exposer.IAZOAtIndex(IAZOCount - 1);
        iazo = await IAZO.at(iazoAddress);
        const iazoStatus = await iazo.getIAZOState();
        assert.equal(
            iazoStatus,
            0,
            "start status should be 0"
        );
    });

    it("iazo status should be in progress when start time is reached", async () => {
        await time.increaseTo(startTimestamp);

        iazoStatus = await iazo.getIAZOState();
        assert.equal(
            iazoStatus.toNumber(),
            1,
            "iazo should now be active"
        );
    });

    it("Users should be able to buy IAZO tokens", async () => {
        await baseToken.mint("400000000000000000", { from: bob });
        await baseToken.approve(iazo.address, "400000000000000000", { from: bob });
        await iazo.userDeposit("400000000000000000", { from: bob });

        const buyerInfo = await iazo.BUYERS.call(bob);
        assert.equal(
            buyerInfo.deposited,
            "400000000000000000",
            "account deposited check"
        );
        assert.equal(
            buyerInfo.tokensBought,
            "200000000000000000",
            "account bought check"
        );
    });

    it("iazo status should be failed", async () => {
        await iazo.forceFailAdmin({ from: adminAddress });
        const iazoStatus = await iazo.getIAZOState();
        assert.equal(
            iazoStatus,
            4,
            "start status should be 4"
        );
    });

    it("Should be able to withdraw tokens after failed IAZO", async () => {
        const balance = await baseToken.balanceOf(bob)
        await iazo.userWithdraw({ from: bob });
        const balanceAfterReceivedTokens = await baseToken.balanceOf(bob)

        assert.equal(
            balanceAfterReceivedTokens - balance,
            "400000000000000000",
            "account deposited check"
        );

        await iazo.withdrawOfferTokensOnFailure({from: alice});
        const afterOfferBalance = (await banana.balanceOf(iazo.address)).toString();
        assert.equal(
            afterOfferBalance,
            "0",
            "offer tokens were not fully removed from contract"
        );
    });
});