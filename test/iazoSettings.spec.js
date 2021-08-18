const { expectRevert, time, ether } = require('@openzeppelin/test-helpers');
const { accounts, contract } = require('@openzeppelin/test-environment');
const { expect, assert } = require('chai');

// Load compiled artifacts
const IAZOSettings = contract.fromArtifact('IAZOSettings');

describe('IAZOSettingsTest', function () {
    const [admin, feeAddress] = accounts;

    it("Should set and get base fee", async () => {
        const settings = await IAZOSettings.new(admin, feeAddress, { from: admin });
        await settings.setFees(15, 15, { from: admin });
        const newBaseFee = await settings.getBaseFee({ from: admin });
        assert.equal(
            newBaseFee,
            15,
        );
    });
});