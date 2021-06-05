const ILOFabric = artifacts.require("ILOFabric");
const ILOSettings = artifacts.require("ILOSettings");
const ILOExposer = artifacts.require("ILOExposer");
const Banana = artifacts.require("Banana");
const WBNB = artifacts.require("WBNB");

contract("ILOFabric", accounts => {
    it("Should transfer ETH fee to fee address and expose ILO address", async () => {
        const fabric = await ILOFabric.deployed();
        const banana = await Banana.deployed();
        const wbnb = await WBNB.deployed();
        const settings = await ILOSettings.deployed();
        const exposerAddress = await fabric.ILO_EXPOSER();
        const exposer = await ILOExposer.at(exposerAddress);

        //Fee check
        const FeeAddress = await settings.getFeeAddress();
        const startBalance = await web3.eth.getBalance(FeeAddress);

        //new contract exposed check
        const startILOCount = await exposer.ILOsLength();

        await banana.mint("1000000000000000000000000", { from: accounts[1] });
        await banana.approve(fabric.address, "1000000000000000000000000", { from: accounts[1] });
        await fabric.createILO(accounts[1], banana.address, wbnb.address, [1, 1000000, 1000000, 10000, 1, 100, 100, 100, 300, 1], { from: accounts[1], value: 1000000000000000000 })

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
});