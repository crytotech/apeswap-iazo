const ILOFabric = artifacts.require("ILOFabric");
const ILO = artifacts.require("ILO");
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

        await banana.mint("2000000000000000000000000", { from: accounts[1] });
        await banana.approve(fabric.address, "2000000000000000000000000", { from: accounts[1] });
        const blockNumber = await web3.eth.getBlockNumber();
        await fabric.createILO(accounts[1], banana.address, wbnb.address, ["1000000000000000000", "1000000000000000000000000", "1000000000000000000000000", "1000000000000000000000", blockNumber + 2, 100, 60, "2000000000000000000000000", 300, 1], { from: accounts[1], value: 1000000000000000000 })

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

        const iloAddress = await exposer.ILOAtIndex(newILOCount - 1);
        const ilo = await ILO.at(iloAddress);

        // ===== GENERAL =====
        // Tests for general stuff

        const balance = await banana.balanceOf(iloAddress);
        assert.equal(
            balance.valueOf(),
            1015000000000000000000000, //1307000, //hardcoded for now because might change the getTokensRequired() function
            "check for received ilo token"
        );

        // ===== QUEUED =====
        // Tests to make sure the ilo is not active yet and can't be interacted with

        //new ilo start status number check
        let iloStatus = await ilo.ILOStatusNumber();
        assert.equal(
            iloStatus,
            0,
            "start status should be 0"
        );





        //just anything to increase block number by 1 so the ilo start block is reached
        web3.eth.sendTransaction({ to: accounts[2], from: accounts[0], value: "1000" })

        // ===== ACTIVE =====
        // Tests to make sure the ilo is not active yet and can't be interacted with

        //new ilo start status number check
        iloStatus = await ilo.ILOStatusNumber();
        assert.equal(
            iloStatus,
            1,
            "ilo should now be active"
        );

        //user deposit / buy ilo token
        await wbnb.mint("10000000000000000000", { from: accounts[2] });
        await wbnb.approve(ilo.address, "10000000000000000000", { from: accounts[2] });
        await ilo.userDeposit("10000000000000000000", { from: accounts[2] });

        let buyerInfo = await ilo.BUYERS.call(accounts[2]);
        assert.equal(
            buyerInfo.deposited,
            "10000000000000000000",
            "account deposited check"
        );

        //user deposit / buy ilo token more than hardcap
        await wbnb.mint("2000000000000000000000000", { from: accounts[3] });
        await wbnb.approve(ilo.address, "2000000000000000000000000", { from: accounts[3] });
        await ilo.userDeposit("2000000000000000000000000", { from: accounts[3] });

        buyerInfo = await ilo.BUYERS.call(accounts[3]);
        console.log(buyerInfo);

        assert.equal(
            buyerInfo.deposited,
            "999990000000000000000000",
            "account deposited check"
        );

        //harcap reached so ilo success
        iloStatus = await ilo.ILOStatusNumber();
        assert.equal(
            iloStatus,
            3,
            "ilo should now be successfull with hardcap reached"
        );

        //withdraw bought banana
        await ilo.userWithdraw({ from: accounts[2] });
        let receivedTokens = await banana.balanceOf(accounts[2])
        assert.equal(
            receivedTokens,
            "10000000000000000000",
            "account deposited check"
        );
    });
}); 