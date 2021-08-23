const { balance, expectRevert, time, ether } = require('@openzeppelin/test-helpers');
const { accounts, contract } = require('@openzeppelin/test-environment');
const { expect, assert } = require('chai');
const { getNetworkConfig } = require("../deploy-config");

const ApeFactoryBuild = require('../build-apeswap-dex/contracts/ApeFactory.json');
const ApeFactory = contract.fromABI(ApeFactoryBuild.abi, ApeFactoryBuild.bytecode);

const ApePairBuild = require('../build-apeswap-dex/contracts/ApePair.json');
const ApePair = contract.fromABI(ApePairBuild.abi, ApePairBuild.bytecode);


// Load compiled artifacts
const ERC20Mock = contract.fromArtifact("ERC20Mock");


describe('DEX', async function () {
    const [minter, feeToSetter, feeTo, alice, bob] = accounts;

    let dexFactory;
    let token0;
    let token1;
    let basePair;
    const startingBalance = ether('1000');


    beforeEach(async () => {
        // Deploy DEX factory
        dexFactory = await ApeFactory.new(feeToSetter, {from: minter});
        // Setup token0
        token0 = await ERC20Mock.new({from: minter});
        await token0.mint(startingBalance, {from: alice})
        await token0.mint(startingBalance, {from: bob})
        // Setup token1
        token1 = await ERC20Mock.new({from:minter}); 
        await token1.mint(startingBalance, {from: alice})
        await token1.mint(startingBalance, {from: bob})
        // Create an initial pair
        await dexFactory.createPair(token0.address, token1.address);
        let pairCreated = await dexFactory.allPairs(0);
        basePair = await ApePair.at(pairCreated);
      });
      
    it("should provide the proper symbol from base pair", async () => {
        let basePairSymbol = await basePair.symbol({from: alice});
        assert.equal(
            basePairSymbol,
            'APE-LP',
            'Base pair symbol is invalid'
        );
    });

    it("should allow minting/burning of LP tokens", async () => {
        let aliceToken0Balance = await token0.balanceOf(alice, {from: alice})
        assert.equal(
            aliceToken0Balance.toString(),
            startingBalance.toString(), // Alice will get 1e18 minus the reserve of 1000
            'Alice base pair balance is invalid'
        );

        let bobToken0Balance = await token0.balanceOf(bob, {from: bob})
        assert.equal(
            bobToken0Balance.toString(),
            startingBalance.toString(),
            'Bob base pair balance is invalid'
        );

        // Add liquidity alice
        await token0.transfer(basePair.address, ether('1'), {from: alice});
        await token1.transfer(basePair.address, ether('1'), {from: alice});
        await basePair.mint(alice, {from: alice});

        let aliceBasePairBalance = await basePair.balanceOf(alice, {from: alice})
        assert.equal(
            aliceBasePairBalance.toString(),
            '999999999999999000', // Alice will get 1e18 minus the reserve of 1000
            'Alice base pair balance is invalid'
        );
        
        // Add liquidty bob
        await token0.transfer(basePair.address, ether('1'), {from: bob});
        await token1.transfer(basePair.address, ether('1'), {from: bob});
        await basePair.mint(bob, {from: bob});

        let bobBasePairBalance = await basePair.balanceOf(bob, {from: bob})
        assert.equal(
            bobBasePairBalance.toString(),
            ether('1').toString(),
            'Bob base pair balance is invalid'
        );

        // Remove liquidity bob
        await basePair.transfer(basePair.address, '1000000000000000000', {from: bob});
        await basePair.burn(bob, {from: bob});
        
        bobBasePairBalance = await basePair.balanceOf(bob, {from: bob})
        assert.equal(
            bobBasePairBalance.toString(),
            '0',
            'Bob base pair balance is invalid'
        );

        bobToken0Balance = await token0.balanceOf(bob, {from: bob})
        assert.equal(
            bobToken0Balance.toString(),
            startingBalance.toString(),
            'Bob token0 balance is invalid'
        );
    });
});