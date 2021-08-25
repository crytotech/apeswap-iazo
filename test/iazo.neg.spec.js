const { balance, expectRevert, time, ether } = require('@openzeppelin/test-helpers');
const { accounts, contract } = require('@openzeppelin/test-environment');
const { expect, assert } = require('chai');
const { getNetworkConfig } = require("../deploy-config");

// Load compiled artifacts
const IAZOFactory = contract.fromArtifact("IAZOFactory");
const IAZO = contract.fromArtifact("IAZO");
const IAZOSettings = contract.fromArtifact("IAZOSettings");
const IAZOExposer = contract.fromArtifact("IAZOExposer");
const Banana = contract.fromArtifact("Banana");
const ERC20Mock = contract.fromArtifact("ERC20Mock");
const IAZOUpgradeProxy = contract.fromArtifact("IAZOUpgradeProxy");
const IAZOLiquidityLocker = contract.fromArtifact("IAZOLiquidityLocker");


describe("IAZO - Negative Tests", async function() {
    const [proxyAdmin, adminAddress] = accounts;
    const { feeAddress, wNative, apeFactory } = getNetworkConfig('development', accounts);

    let factory = null;
    let banana = null;
    let baseToken = null;
    let settings = null;
    let exposer = null;
    let iazo = null;
    let admin = null;
    let liquidity = null;

    it("Should set all contract variables", async () => {
        banana = await ERC20Mock.new();
        baseToken = await ERC20Mock.new();
        iazo = await IAZO.new();
        exposer = await IAZOExposer.new();
        await exposer.transferOwnership(adminAddress);
        settings = await IAZOSettings.new(adminAddress, feeAddress);

        const liquidityLockerContract = await IAZOLiquidityLocker.new();
        const liquidityProxy = await IAZOUpgradeProxy.new(proxyAdmin, liquidityLockerContract.address, '0x');
        liquidity = await IAZOLiquidityLocker.at(liquidityProxy.address);
        await liquidity.initialize(exposer.address, apeFactory, settings.address, adminAddress);

        const factoryContract = await IAZOFactory.new();
        const factoryProxy = await IAZOUpgradeProxy.new(proxyAdmin, factoryContract.address, '0x');
        factory = await IAZOFactory.at(factoryProxy.address);
        factory.initialize(exposer.address, settings.address, liquidity.address, iazo.address, wNative, adminAddress);
    });

    it("Should create and expose new IAZO", async () => {
        const FeeAddress = await settings.getFeeAddress();
        const startBalance = await balance.current(FeeAddress, unit = 'wei')

        const startIAZOCount = await exposer.IAZOsLength();

        await banana.mint("2000000000000000000000000", { from: accounts[1] });
        await banana.approve(factory.address, "2000000000000000000000000", { from: accounts[1] });
        const startTimestamp = (await time.latest()) + 10;
        await factory.createIAZO(
            accounts[1], 
            banana.address, 
            baseToken.address, 
            true, 
            false, 
            [
                "2000000000000000000", // token price
                "1000000000000000000000000", // amount
                "1000000000000000000000", // softcap
                startTimestamp, // start time
                43201, // active time
                2419000, // lock period
                "2000000000000000000000000", // max spend per buyer
                "300", // liquidity percent
                0 // listing price
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

    it("iazo status should be failed", async () => {
        await iazo.forceFailAdmin({ from: adminAddress });
        const iazoStatus = await iazo.getIAZOState();
        assert.equal(
            iazoStatus,
            4,
            "start status should be 4"
        );
    });
});