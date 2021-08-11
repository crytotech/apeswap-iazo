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

    it("Should create and expose new IAZO", async () => {
        const FeeAddress = await settings.getFeeAddress();
        const startBalance = await web3.eth.getBalance(FeeAddress);

        const startIAZOCount = await exposer.IAZOsLength();

        await banana.mint("2000000000000000000000000", { from: accounts[1] });
        await banana.approve(factory.address, "2000000000000000000000000", { from: accounts[1] });
        const blockNumber = await web3.eth.getBlockNumber();
        await factory.createIAZO(accounts[1], banana.address, wnative.address, true, false, ["2000000000000000000", "1000000000000000000000000", "1000000000000000000000", blockNumber + 2, 28700, 60, "2000000000000000000000000", 30, 0], { from: accounts[1], value: 1000000000000000000 })

        //Fee check2
        const newBalance = await web3.eth.getBalance(FeeAddress);

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
        await iazo.forceFailAdmin({ from: accounts[0] });
        const iazoStatus = await iazo.getIAZOState();
        assert.equal(
            iazoStatus,
            4,
            "start status should be 4"
        );
    });
});