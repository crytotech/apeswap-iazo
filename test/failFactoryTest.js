const truffleAssert = require('truffle-assertions');

const IAZOFactory = artifacts.require("IAZOFactory");
const IAZO = artifacts.require("IAZO");
const IAZOSettings = artifacts.require("IAZOSettings");
const IAZOExposer = artifacts.require("IAZOExposer");
const Banana = artifacts.require("Banana");
const WNATIVE = artifacts.require("WNativeMock");
const IAZOUpgradeProxy = artifacts.require("IAZOUpgradeProxy");
const ProxyAdminContract = artifacts.require("ProxyAdmin.sol");
const IAZOLiquidityLocker = artifacts.require("IAZOLiquidityLocker");

const { getNetworkConfig } = require("../deploy-config");

contract("Simple test", async (accounts) => {
    const { adminAddress, feeAddress, wNative, apeFactory } = getNetworkConfig('development', accounts);

    let factory = null;
    let banana = null;
    let wnative = null;
    let settings = null;
    let exposer = null;
    let iazo = null;
    let admin = null;
    let liquidity = null;

    it("Should set all contract variables", async () => {
        banana = await Banana.deployed();
        wnative = await WNATIVE.deployed();
        iazo = await IAZO.new();
        exposer = await IAZOExposer.new();
        await exposer.transferOwnership(adminAddress);
        settings = await IAZOSettings.new(adminAddress, feeAddress);
        admin = await ProxyAdminContract.new();

        const liquidityLockerContract = await IAZOLiquidityLocker.new();
        const abiEncodeDataLiquidityLocker = web3.eth.abi.encodeFunctionCall(
            {
                "inputs": [
                    {
                        "internalType": "address",
                        "name": "iazoExposer",
                        "type": "address"
                    },
                    {
                        "internalType": "address",
                        "name": "apeFactory",
                        "type": "address"
                    },
                    {
                        "internalType": "address",
                        "name": "iazoSettings",
                        "type": "address"
                    },
                    {
                        "internalType": "address",
                        "name": "admin",
                        "type": "address"
                    }
                ],
                "name": "initialize",
                "outputs": [],
                "stateMutability": "nonpayable",
                "type": "function"
            },
            [
                exposer.address,
                apeFactory,
                settings.address,
                admin.address
            ]
        );
        const liquidityProxy = await IAZOUpgradeProxy.new(admin.address, liquidityLockerContract.address, abiEncodeDataLiquidityLocker);
        liquidity = await IAZOLiquidityLocker.at(liquidityProxy.address);

        const factoryContract = await IAZOFactory.new();
        const abiEncodeDataFactory = web3.eth.abi.encodeFunctionCall(
            {
                "inputs": [
                    {
                        "internalType": "contract IIAZO_EXPOSER",
                        "name": "iazoExposer",
                        "type": "address"
                    },
                    {
                        "internalType": "contract IIAZOSettings",
                        "name": "iazoSettings",
                        "type": "address"
                    },
                    {
                        "internalType": "contract IIAZOLiquidityLocker",
                        "name": "iazoliquidityLocker",
                        "type": "address"
                    },
                    {
                        "internalType": "contract IIAZO",
                        "name": "iazoInitialImplementation",
                        "type": "address"
                    },
                    {
                        "internalType": "contract IWNative",
                        "name": "wnative",
                        "type": "address"
                    },
                    {
                        "internalType": "address",
                        "name": "admin",
                        "type": "address"
                    }
                ],
                "name": "initialize",
                "outputs": [],
                "stateMutability": "nonpayable",
                "type": "function"
            },
            [
                exposer.address,
                settings.address,
                liquidity.address,
                iazo.address,
                wNative,
                admin.address
            ]
        );
        const factoryProxy = await IAZOUpgradeProxy.new(admin.address, factoryContract.address, abiEncodeDataFactory);
        factory = await IAZOFactory.at(factoryProxy.address);
    });

    it("Should revert iazo creation, exceeds balance", async () => {
        const blockNumber = await web3.eth.getBlockNumber();
        await truffleAssert.reverts(
            factory.createIAZO(accounts[1], banana.address, wnative.address, true, false, ["2000000000000000000", "1000000000000000000000000", "1000000000000000000000", blockNumber + 2, 28700, 60, "2000000000000000000000000", 30, 0], { from: accounts[1], value: 1000000000000000000 })
        );
    });
    it("Should revert iazo creation, exceeds approved balance", async () => {
        await banana.mint("2000000000000000000000000", { from: accounts[1] });
        const blockNumber = await web3.eth.getBlockNumber();
        await truffleAssert.reverts(
            factory.createIAZO(accounts[1], banana.address, wnative.address, true, false, ["2000000000000000000", "1000000000000000000000000", "1000000000000000000000", blockNumber + 2, 28700, 60, "2000000000000000000000000", 30, 0], { from: accounts[1], value: 1000000000000000000 })
        );
    });
    it("Should revert iazo creation, fee not met", async () => {
        await banana.approve(factory.address, "2000000000000000000000000", { from: accounts[1] });
        const blockNumber = await web3.eth.getBlockNumber();
        await truffleAssert.reverts(
            factory.createIAZO(accounts[1], banana.address, wnative.address, true, false, ["2000000000000000000", "1000000000000000000000000", "1000000000000000000000", blockNumber + 2, 28700, 60, "2000000000000000000000000", 30, 0], { from: accounts[1] }),
            "Fee not met"
        );
    });
    it("Should revert iazo creation, start iazo past block", async () => {
        const blockNumber = await web3.eth.getBlockNumber();
        await truffleAssert.reverts(
            factory.createIAZO(accounts[1], banana.address, wnative.address, true, false, ["2000000000000000000", "1000000000000000000000000", "1000000000000000000000", blockNumber - 1, 28700, 60, "2000000000000000000000000", 30, 0], { from: accounts[1], value: 1000000000000000000 }),
            "iazo should start in future"
        );
    });
    it("Should revert iazo creation, iazo not long enough", async () => {
        const blockNumber = await web3.eth.getBlockNumber();
        await truffleAssert.reverts(
            factory.createIAZO(accounts[1], banana.address, wnative.address, true, false, ["2000000000000000000", "1000000000000000000000000", "1000000000000000000000", blockNumber + 2, 200, 60, "2000000000000000000000000", 30, 0], { from: accounts[1], value: 1000000000000000000 }),
            "iazo length not long enough"
        );
    });
    it("Should revert iazo creation, iazo too long", async () => {
        const blockNumber = await web3.eth.getBlockNumber();
        await truffleAssert.reverts(
            factory.createIAZO(accounts[1], banana.address, wnative.address, true, false, ["2000000000000000000", "1000000000000000000000000", "1000000000000000000000", blockNumber + 2, 1602700, 60, "2000000000000000000000000", 30, 0], { from: accounts[1], value: 1000000000000000000 }),
            "Exceeds max iazo length"
        );
    });
    it("Should revert iazo creation, amount not enough", async () => {
        const blockNumber = await web3.eth.getBlockNumber();
        await truffleAssert.reverts(
            factory.createIAZO(accounts[1], banana.address, wnative.address, true, false, ["2000000000000000000", "999", "1000000000000000000000", blockNumber + 2, 28700, 60, "2000000000000000000000000", 30, 0], { from: accounts[1], value: 1000000000000000000 }),
            "Minimum divisibility"
        );
    });
    it("Should revert iazo creation, invalid token price", async () => {
        const blockNumber = await web3.eth.getBlockNumber();
        await truffleAssert.reverts(
            factory.createIAZO(accounts[1], banana.address, wnative.address, true, false, ["0", "1000000000000000000000000", "1000000000000000000000", blockNumber + 2, 28700, 60, "2000000000000000000000000", 30, 0], { from: accounts[1], value: 1000000000000000000 }),
            "Invalid token price"
        );
    });
    it("Should revert iazo creation, percentage liquidity too low", async () => {
        const blockNumber = await web3.eth.getBlockNumber();
        await truffleAssert.reverts(
            factory.createIAZO(accounts[1], banana.address, wnative.address, true, false, ["2000000000000000000", "1000000000000000000000000", "1000000000000000000000", blockNumber + 2, 28700, 60, "2000000000000000000000000", 29, 0], { from: accounts[1], value: 1000000000000000000 }),
            "Liquidity percentage too low"
        );
    });
});