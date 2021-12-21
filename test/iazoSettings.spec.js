const { expectRevert, time, ether, balance } = require('@openzeppelin/test-helpers');
const { accounts, contract } = require('@openzeppelin/test-environment');
const { expect, assert } = require('chai');

// Load compiled artifacts
const IAZOSettings = contract.fromArtifact('IAZOSettings');

describe('IAZOSettingsTest', function () {
    const [admin, feeAddress, bob, carol] = accounts;
    let settings;

    it("Should set all contract variables", async () => {
        settings = await IAZOSettings.new(admin, feeAddress, { from: admin });
    });

    it("Should set and get max iazo length", async () => {
        let maxIAZOLength = await settings.getMaxIAZOLength({ from: admin });
        assert.equal(
            maxIAZOLength,
            1814000,
        );

        await settings.setMaxIAZOLength(814000, { from: admin });
        maxIAZOLength = await settings.getMaxIAZOLength({ from: admin });
        assert.equal(
            maxIAZOLength,
            814000,
        );
    });

    it("Should set and get min iazo length", async () => {
        let minIAZOLength = await settings.getMinIAZOLength({ from: admin });
        assert.equal(
            minIAZOLength,
            43200,
        );

        await settings.setMinIAZOLength(23200, { from: admin });
        minIAZOLength = await settings.getMinIAZOLength({ from: admin });
        assert.equal(
            minIAZOLength,
            23200,
        );
    });

    it("Should set and get fees", async () => {
        let baseFee = await settings.getBaseFee({ from: admin });
        assert.equal(
            baseFee,
            50,
        );
        let maxBaseFee = await settings.getMaxBaseFee({ from: admin });
        assert.equal(
            maxBaseFee,
            300,
        );
        let nativeCreationFee = await settings.getNativeCreationFee({ from: admin });
        assert.equal(
            nativeCreationFee,
            "10000000000000000000",
        );

        await settings.setMaxLiquidityPercent(940, { from: admin });
        await settings.setFees(60, 50, "2000000000000000000", { from: admin });
        baseFee = await settings.getBaseFee({ from: admin });
        assert.equal(
            baseFee,
            60,
        );
        iazoTokenFee = await settings.getIAZOTokenFee({ from: admin });
        assert.equal(
            iazoTokenFee,
            50,
        );
        nativeCreationFee = await settings.getNativeCreationFee({ from: admin });
        assert.equal(
            nativeCreationFee,
            "2000000000000000000",
        );
    });

    it("Should set and get min lock period", async () => {
        let minLockPeriod = await settings.getMinLockPeriod({ from: admin });
        assert.equal(
            minLockPeriod,
            2419000,
        );

        await settings.setMinLockPeriod(419000, { from: admin });
        minLockPeriod = await settings.getMinLockPeriod({ from: admin });
        assert.equal(
            minLockPeriod,
            419000,
        );
    });
    
    it("Should set and get admin address", async () => {
        let adminAddress = await settings.getAdminAddress({ from: admin });
        assert.equal(
            adminAddress,
            admin,
        );

        await settings.setAdminAddress(bob, { from: admin });
        adminAddress = await settings.getAdminAddress({ from: admin });
        assert.equal(
            adminAddress,
            bob,
        );
    });

    it("Should set and get fee address", async () => {
        let _feeAddress = await settings.getFeeAddress({ from: bob });
        assert.equal(
            _feeAddress,
            feeAddress,
        );
        
        const tracker = await balance.tracker(bob);

        const txReceipt = await settings.setFeeAddress(carol, { from: bob, value: ether('10') });
        _feeAddress = await settings.getFeeAddress({ from: bob });
        assert.equal(
            _feeAddress,
            carol,
        );

        const txFee = txReceipt.receipt.gasUsed * 20000000000; // 20 Gwei default gasPrice
        const balanceDelta = (await tracker.delta()).toNumber() * -1

        assert.equal(
            balanceDelta - txFee,
            1,
            'refund did not appear to work'
        );
    });
});