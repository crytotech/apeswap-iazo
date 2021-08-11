const IAZOSettings = artifacts.require("IAZOSettings");

contract("IAZOSettings", accounts => {
    it("Should set and get base fee", async () => {
        const settings = await IAZOSettings.deployed();
        await settings.setFees(15, 15);
        const newBaseFee = await settings.getBaseFee();
        assert.equal(
            newBaseFee,
            15,
        );
    });
});