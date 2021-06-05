const ILOSettings = artifacts.require("ILOSettings");

contract("ILOSettings", accounts => {
    it("Should set and get base fee", async () => {
        const settings = await ILOSettings.deployed();
        await settings.setFees(15, 15, 15);
        const newBaseFee = await settings.getBaseFee();
        assert.equal(
            newBaseFee,
            15,
        );
    });
});