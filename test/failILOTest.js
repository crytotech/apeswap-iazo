const truffleAssert = require('truffle-assertions');

const ILOFabric = artifacts.require("ILOFabric");
const ILO = artifacts.require("ILO");
const ILOSettings = artifacts.require("ILOSettings");
const ILOExposer = artifacts.require("ILOExposer");
const Banana = artifacts.require("Banana");
const WBNB = artifacts.require("WBNB");

contract("Failed ILO", async (accounts) => {
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

    it("Should create and expose new ILO", async () => {
        const FeeAddress = await settings.getFeeAddress();
        const startBalance = await web3.eth.getBalance(FeeAddress);

        const startILOCount = await exposer.ILOsLength();

        await banana.mint("2000000000000000000000000", { from: accounts[1] });
        await banana.approve(fabric.address, "2000000000000000000000000", { from: accounts[1] });
        const blockNumber = await web3.eth.getBlockNumber();
        await fabric.createILO(accounts[1], banana.address, wbnb.address, true, ["2000000000000000000", "1000000000000000000000000", "1000000000000000000000000", "1000000000000000000000", blockNumber + 2, 28700, 60, "2000000000000000000000000", 300, 1], { from: accounts[1], value: 1000000000000000000 })

        //Fee check2
        const newBalance = await web3.eth.getBalance(FeeAddress);

        assert.equal(
            newBalance - startBalance,
            1000000000000000000,
        );

        //new contract exposed check2
        const newILOCount = await exposer.ILOsLength();
        assert.equal(
            newILOCount - startILOCount,
            1,
        );
    });

    it("ilo status should be queued", async () => {
        const ILOCount = await exposer.ILOsLength();
        const iloAddress = await exposer.ILOAtIndex(ILOCount - 1);
        ilo = await ILO.at(iloAddress);
        const iloStatus = await ilo.ILOStatusNumber();
        assert.equal(
            iloStatus,
            0,
            "start status should be 0"
        );
    });

    it("ilo status should be failed", async () => {
        await ilo.forceFailAdmin({ from: accounts[0] });
        const iloStatus = await ilo.ILOStatusNumber();
        assert.equal(
            iloStatus,
            4,
            "start status should be 4"
        );
    });
}); 