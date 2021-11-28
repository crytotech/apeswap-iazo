import { ethers, Contract, Wallet } from 'ethers';
import truffleConfig from '../truffle-config';

import IAZOFactoryArtifact from '../build/contracts/IAZOFactory.json'
import ERC20 from '../build/contracts/ERC20.json'

const MAINNET_DEPLOYER_KEY = process.env.MAINNET_DEPLOYER_KEY || '';
const TESTNET_DEPLOYER_KEY = process.env.TESTNET_DEPLOYER_KEY || '';
const TESTNET_PK = process.env.TESTNET_PK || '';
const TESTNET_URL = 'https://data-seed-prebsc-1-s1.binance.org:8545'

async function getProviderAccounts(provider): Promise<Array<string>> {
    return await provider.listAccounts()
}

function getTimestamp(offset = 0) {
    return Math.floor(Date.now() / 1000) + offset;
}

function ether(amount: string) {
    return amount + '000000000000000000'
}

const IAZO_TOKEN = '0x016D94FB3f8689985430b247B2A2611db6522371'
const BASE_TOKEN = '0x68D24FA18c00B5Df32e91C1dDDfa6419083606F9'
const TESTNET_IAZO_FACTORY = '0xed344dFafe5999B0F4e1880DbF794EbE4720C859' // new

async function createIAZO() {
    const NETWORK = 'bsc-testnet';
    const networkConfig = truffleConfig.networks[NETWORK];
    if (networkConfig == undefined) {
        throw new Error(`${NETWORK} network not found in config.`)
    }

    const provider = ethers.getDefaultProvider(TESTNET_URL) ;
    // PK wallet
    let wallet = new Wallet(TESTNET_PK, provider);

    const currentAccount = wallet.address;
    console.dir({currentAccount})

    const iazoFactory = new Contract(TESTNET_IAZO_FACTORY, IAZOFactoryArtifact.abi, wallet);

    const iazoToken = new Contract(IAZO_TOKEN, ERC20.abi, wallet);
    const baseToken = new Contract(BASE_TOKEN, ERC20.abi, wallet);

    await iazoToken.approve(iazoFactory.address, ether('999999999'))

    console.log(`Approved IAZOFactory ${iazoFactory.address} to transfer IAZO Token ${iazoToken.address}`)

    const receipt = await iazoFactory.createIAZO(
        currentAccount,          //  _IAZOOwner,
        IAZO_TOKEN,              //  _IAZOToken,
        BASE_TOKEN,              //  _baseToken,
        true,                    //  _burnRemains,
        [
            '1000000000000000000', // TOKEN_PRICE;
            ether('1000'),      // AMOUNT (hardcap)
            ether('50'),     // SOFTCAP
            getTimestamp(100), // START_TIME (unix timestamp)
            43200,          // ACTIVE_TIME (seconds)
            2419000,        // LOCK_PERIOD (seconds)
            ether('1'),     // MAX_SPEND_PER_BUYER
            500,            // LIQUIDITY_PERCENT
            0,              // LISTING_PRICE (if 0 same as TOKEN_PRICE)
        ],
        { value: ether('10') }
    );

    console.dir(receipt);
}


(async function () {
    try {
        await createIAZO();
        process.exit(0)
    } catch (e) {
        console.error(e);
        process.exit(1)
    }
}());