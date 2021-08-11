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
        await factory.createIAZO(accounts[1], banana.address, wnative.address, true, false, ["100000000000000000", "21000000000000000000", "1000000000000000000", blockNumber + 2, 28700, 60, "2000000000000000000000000", "30", "200000000000000000"], { from: accounts[1], value: 1000000000000000000 })

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

    it("iazo status should be in progress when start block reached", async () => {
        //just anything to increase block number by 1 so the iazo start block is reached
        web3.eth.sendTransaction({ to: accounts[2], from: accounts[0], value: "1000" })

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
        const allowance = await wnative.allowance(iazo.address, locker.address);

        assert.equal(
            allowance,
            "630000000000000000",
            "wrong allowance"
        );
    });

    it("Should approve locker to spend iazo token", async () => {
        const allowance = await banana.allowance(iazo.address, locker.address);

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