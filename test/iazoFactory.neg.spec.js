const { expectRevert, time, ether } = require('@openzeppelin/test-helpers');
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
const IAZOTokenTimelock = contract.fromArtifact("IAZOTokenTimelock");


describe('IAZOFactory - Negative Tests', function () {
    const [proxyAdmin, adminAddress] = accounts;
    const { feeAddress, wNative, apeFactory } = getNetworkConfig('development', accounts);

    let factory = null;
    let settings = null;
    let exposer = null;
    let iazo = null;
    let admin = null;
    let liquidity = null;
    let tokenTimelock = null;

    beforeEach(async () => {
        this.banana = await ERC20Mock.new();
        this.baseToken = await ERC20Mock.new();
    });

    it("Should set all contract variables", async () => {
        iazo = await IAZO.new();
        exposer = await IAZOExposer.new();
        await exposer.transferOwnership(adminAddress);
        settings = await IAZOSettings.new(adminAddress, feeAddress);
        tokenTimelock = await IAZOTokenTimelock.new();

        const liquidityLockerContract = await IAZOLiquidityLocker.new();
        const liquidityProxy = await IAZOUpgradeProxy.new(proxyAdmin, liquidityLockerContract.address, '0x');
        liquidity = await IAZOLiquidityLocker.at(liquidityProxy.address);
        await liquidity.initialize(exposer.address, apeFactory, settings.address, adminAddress, tokenTimelock.address);

        const factoryContract = await IAZOFactory.new();
        const factoryProxy = await IAZOUpgradeProxy.new(proxyAdmin, factoryContract.address, '0x');
        factory = await IAZOFactory.at(factoryProxy.address);
        await factory.initialize(exposer.address, settings.address, liquidity.address, iazo.address, wNative, adminAddress)
    });

    it("Should revert iazo creation, exceeds balance", async () => {
        const iazoStartTime = (await time.latest()).toNumber() + 624000 + 100;
        await expectRevert(
            factory.createIAZO(accounts[1], this.banana.address, this.baseToken.address, false, ["2000000000000000000", "1000000000000000000000000", "1000000000000000000000", iazoStartTime, 43201, 2419000, "2000000000000000000000000", 300, 0], { from: accounts[1], value: 10000000000000000000 },),
            'ERC20: transfer amount exceeds balance.'
        );
    });
    it("Should revert iazo creation, exceeds approved balance", async () => {
        await this.banana.mint("2000000000000000000000000", { from: accounts[1] });
        const iazoStartTime = (await time.latest()).toNumber() + 624000 + 100;
        await expectRevert(
            factory.createIAZO(accounts[1], this.banana.address, this.baseToken.address, false, ["2000000000000000000", "1000000000000000000000000", "1000000000000000000000", iazoStartTime, 43201, 2419000, "2000000000000000000000000", 300, 0], { from: accounts[1], value: 10000000000000000000 }),
            'ERC20: transfer amount exceeds allowance.'
        );
    });
    it("Should revert iazo creation, fee not met", async () => {
        await this.banana.approve(factory.address, "2000000000000000000000000", { from: accounts[1] });
        const iazoStartTime = (await time.latest()).toNumber() + 624000 + 100;
        await expectRevert(
            factory.createIAZO(accounts[1], this.banana.address, this.baseToken.address, false, ["2000000000000000000", "1000000000000000000000000", "1000000000000000000000", iazoStartTime, 43201, 2419000, "2000000000000000000000000", 300, 0], { from: accounts[1] }),
            "Fee not met"
        );
    });
    it("Should revert iazo creation, start time before start delay", async () => {
        const iazoStartTime = (await time.latest()).toNumber() + 10;
        await expectRevert(
            factory.createIAZO(accounts[1], this.banana.address, this.baseToken.address, false, ["2000000000000000000", "1000000000000000000000000", "1000000000000000000000", iazoStartTime, 43201, 2419000, "2000000000000000000000000", 300, 0], { from: accounts[1], value: 10000000000000000000 }),
            "start delay too short"
        );
    });
    it("Should revert iazo creation, iazo not long enough", async () => {
        const iazoStartTime = (await time.latest()).toNumber() + 624000 + 100;
        await expectRevert(
            factory.createIAZO(accounts[1], this.banana.address, this.baseToken.address, false, ["2000000000000000000", "1000000000000000000000000", "1000000000000000000000", iazoStartTime, 200, 2419000, "2000000000000000000000000", 300, 0], { from: accounts[1], value: 10000000000000000000 }),
            "iazo length not long enough"
        );
    });
    it("Should revert iazo creation, iazo too long", async () => {
        const iazoStartTime = (await time.latest()).toNumber() + 624000 + 100;
        await expectRevert(
            factory.createIAZO(accounts[1], this.banana.address, this.baseToken.address, false, ["2000000000000000000", "1000000000000000000000000", "1000000000000000000000", iazoStartTime, 1814001, 2419000, "2000000000000000000000000", 300, 0], { from: accounts[1], value: 10000000000000000000 }),
            "exceeds max iazo length"
        );
    });
    it("Should revert iazo creation, amount not enough", async () => {
        const iazoStartTime = (await time.latest()).toNumber() + 624000 + 100;
        await expectRevert(
            factory.createIAZO(accounts[1], this.banana.address, this.baseToken.address, false, ["2000000000000000000", "999", "1000000000000000000000", iazoStartTime, 43201, 2419000, "2000000000000000000000000", 300, 0], { from: accounts[1], value: 10000000000000000000 }),
            "amount is less than minimum divisibility"
        );
    });
    it("Should revert iazo creation, invalid token price", async () => {
        const iazoStartTime = (await time.latest()).toNumber() + 624000 + 100;
        await expectRevert(
            factory.createIAZO(accounts[1], this.banana.address, this.baseToken.address, false, ["0", "1000000000000000000000000", "1000000000000000000000", iazoStartTime, 43201, 2419000, "2000000000000000000000000", 300, 0], { from: accounts[1], value: 10000000000000000000 }),
            "hardcap cannot be zero, please check the token price"
        );
    });
    it("Should revert iazo creation, percentage liquidity too low", async () => {
        const iazoStartTime = (await time.latest()).toNumber() + 624000 + 100;
        await expectRevert(
            factory.createIAZO(accounts[1], this.banana.address, this.baseToken.address, false, ["2000000000000000000", "1000000000000000000000000", "1000000000000000000000", iazoStartTime, 43201, 2419000, "2000000000000000000000000", 299, 0], { from: accounts[1], value: 10000000000000000000 }),
            "liquidity percentage out of range"
        );
    });
    
    it("Should revert iazo creation, percentage liquidity too low", async () => {
        const iazoStartTime = (await time.latest()).toNumber() + 624000 + 100;
        await expectRevert(
            factory.createIAZO(accounts[1], this.banana.address, this.baseToken.address, false, ["2000000000000000000", "1000000000000000000000000", "1000000000000000000000", iazoStartTime, 43201, 2419000, "2000000000000000000000000", 299, 0], { from: accounts[1], value: 10000000000000000000 }),
            "liquidity percentage out of range"
        );
    });
});