const { expectRevert, time, ether } = require('@openzeppelin/test-helpers');
const { accounts, contract } = require('@openzeppelin/test-environment');
const { expect, assert } = require('chai');

// Load compiled artifacts
const IAZOSettings = contract.fromArtifact('IAZOSettings');

describe('IAZOSettingsTest', function () {
    const [admin, feeAddress, bob] = accounts;
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
            "1000000000000000000",
        );

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

    it("Should set and get burn address", async () => {
        let burnAddress = await settings.getBurnAddress({ from: admin });
        assert.equal(
            burnAddress,
            "0x000000000000000000000000000000000000dEaD",
        );

        await settings.setBurnAddress(bob, { from: admin });
        burnAddress = await settings.getBurnAddress({ from: admin });
        assert.equal(
            burnAddress,
            bob,
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

        await settings.setFeeAddress(bob, { from: bob });
        _feeAddress = await settings.getFeeAddress({ from: bob });
        assert.equal(
            _feeAddress,
            bob,
        );
    });

    
});