const truffleAssert = require('truffle-assertions');

const ILOFabric = artifacts.require("ILOFabric");
const ILO = artifacts.require("ILO");
const ILOSettings = artifacts.require("ILOSettings");
const ILOExposer = artifacts.require("ILOExposer");
const Banana = artifacts.require("Banana");
const WBNB = artifacts.require("WBNB");

contract("Failed ILO creation", async (accounts) => {
    let fabric = null;
    let banana = null;
    let wbnb = null;
    let settings = null;
    let exposerAddress = null;
    let exposer = null;
    let ilo = null;

    it("Should set all contract variables", async () => {
        fabric = await ILOFabric.deployed();
        banana = await Banana.deployed();
        wbnb = await WBNB.deployed();
        settings = await ILOSettings.deployed();
        exposerAddress = await fabric.ILO_EXPOSER();
        exposer = await ILOExposer.at(exposerAddress);
    });

    it("Should revert ilo creation, exceeds balance", async () => {
        const blockNumber = await web3.eth.getBlockNumber();
        await truffleAssert.reverts(
            fabric.createILO(accounts[1], banana.address, wbnb.address, true, false, ["2000000000000000000", "1000000000000000000000000", "1000000000000000000000", blockNumber + 2, 28700, 60, "2000000000000000000000000", 30, 0], { from: accounts[1], value: 1000000000000000000 })
        );
    });
    it("Should revert ilo creation, exceeds approved balance", async () => {
        await banana.mint("2000000000000000000000000", { from: accounts[1] });
        const blockNumber = await web3.eth.getBlockNumber();
        await truffleAssert.reverts(
            fabric.createILO(accounts[1], banana.address, wbnb.address, true, false, ["2000000000000000000", "1000000000000000000000000", "1000000000000000000000", blockNumber + 2, 28700, 60, "2000000000000000000000000", 30, 0], { from: accounts[1], value: 1000000000000000000 })
        );
    });
    it("Should revert ilo creation, fee not met", async () => {
        await banana.approve(fabric.address, "2000000000000000000000000", { from: accounts[1] });
        const blockNumber = await web3.eth.getBlockNumber();
        await truffleAssert.reverts(
            fabric.createILO(accounts[1], banana.address, wbnb.address, true, false, ["2000000000000000000", "1000000000000000000000000", "1000000000000000000000", blockNumber + 2, 28700, 60, "2000000000000000000000000", 30, 0], { from: accounts[1] }),
            "Fee not met"
        );
    });
    it("Should revert ilo creation, start ilo past block", async () => {
        const blockNumber = await web3.eth.getBlockNumber();
        await truffleAssert.reverts(
            fabric.createILO(accounts[1], banana.address, wbnb.address, true, false, ["2000000000000000000", "1000000000000000000000000", "1000000000000000000000", blockNumber - 1, 28700, 60, "2000000000000000000000000", 30, 0], { from: accounts[1], value: 1000000000000000000 }),
            "ilo should start in future"
        );
    });
    it("Should revert ilo creation, ilo not long enough", async () => {
        const blockNumber = await web3.eth.getBlockNumber();
        await truffleAssert.reverts(
            fabric.createILO(accounts[1], banana.address, wbnb.address, true, false, ["2000000000000000000", "1000000000000000000000000", "1000000000000000000000", blockNumber + 2, 200, 60, "2000000000000000000000000", 30, 0], { from: accounts[1], value: 1000000000000000000 }),
            "ilo length not long enough"
        );
    });
    it("Should revert ilo creation, ilo too long", async () => {
        const blockNumber = await web3.eth.getBlockNumber();
        await truffleAssert.reverts(
            fabric.createILO(accounts[1], banana.address, wbnb.address, true, false, ["2000000000000000000", "1000000000000000000000000", "1000000000000000000000", blockNumber + 2, 1602700, 60, "2000000000000000000000000", 30, 0], { from: accounts[1], value: 1000000000000000000 }),
            "Exceeds max ilo length"
        );
    });
    it("Should revert ilo creation, amount not enough", async () => {
        const blockNumber = await web3.eth.getBlockNumber();
        await truffleAssert.reverts(
            fabric.createILO(accounts[1], banana.address, wbnb.address, true, false, ["2000000000000000000", "999", "1000000000000000000000", blockNumber + 2, 28700, 60, "2000000000000000000000000", 30, 0], { from: accounts[1], value: 1000000000000000000 }),
            "Minimum divisibility"
        );
    });
    it("Should revert ilo creation, invalid token price", async () => {
        const blockNumber = await web3.eth.getBlockNumber();
        await truffleAssert.reverts(
            fabric.createILO(accounts[1], banana.address, wbnb.address, true, false, ["0", "1000000000000000000000000", "1000000000000000000000", blockNumber + 2, 28700, 60, "2000000000000000000000000", 30, 0], { from: accounts[1], value: 1000000000000000000 }),
            "Invalid token price"
        );
    });
    it("Should revert ilo creation, percentage liquidity too low", async () => {
        const blockNumber = await web3.eth.getBlockNumber();
        await truffleAssert.reverts(
            fabric.createILO(accounts[1], banana.address, wbnb.address, true, false, ["2000000000000000000", "1000000000000000000000000", "1000000000000000000000", blockNumber + 2, 28700, 60, "2000000000000000000000000", 29, 0], { from: accounts[1], value: 1000000000000000000 }),
            "Liquidity percentage too low"
        );
    });
}); 