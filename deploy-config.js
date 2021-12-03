
// interface DeployConfig {
//     adminAddress: string;
//     wNative: string;
// }

const isBscMainnet = (network) => ["bsc", "bsc-fork"].includes(network);
const isBscTestnet = (network) => ['bsc-testnet', 'bsc-testnet-fork'].includes(network);
const isDevelopment = (network) => ['development'].includes(network);

function isMainnet(network) {
    if (isBscMainnet(network)) {
        console.log(`This network is evaluated to be a MAINNET network.`)
        return true;
    } else {
        console.log(`This network is evaluated to be a DEVELOPMENT/TESTNET network.`)
        return false;
    }
}

function isDevelopmentNetwork(network) {
    if (
        isBscTestnet(network) ||
        isDevelopment(network)
    ) {
        console.log(`This network is evaluated to be a DEVELOPMENT/TESTNET network.`)
        return true;
    } else {
        console.log(`This network is evaluated to be a MAINNET network.`)
        return false;
    }
}

function getNetworkConfig(network, accounts) {
    if (isBscMainnet(network)) {
        console.log(`Deploying with BSC MAINNET config.`)
        return {
            proxyAdminAddress: '0xf81A0Ee9BB9606e375aeff30364FfA17Bb8a7FD1', // General Proxy admin 
            adminAddress: '0x6c905b4108A87499CEd1E0498721F2B831c6Ab13', // General Admin
            // NOTE: feeAddress MUST be able to receive BNB
            feeAddress: '0x845B9145A46cb659Bd19C463A23e0aD2E38746cf', // SS-IAO fee receiver
            wNative: '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c',
            apeFactory: '0x0841BD0B734E4F5853f0dD8d7Ea041c241fb0Da6',
        }
    } else if (isBscTestnet(network)) {
        console.log(`Deploying with BSC testnet config.`)
        return {
            proxyAdminAddress: '0x56Cb8F9199A8F43933cAE300Ef548dfA4ADE7Da0',
            adminAddress: '0xE375D169F8f7bC18a544a6e5e546e63AD7511581',
            feeAddress: '0xE375D169F8f7bC18a544a6e5e546e63AD7511581',
            wNative: '0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd',
            apeFactory: '0x152349604d49c2Af10ADeE94b918b051104a143E',
        }
    } else if (isDevelopment(network)) {
        console.log(`Deploying with development config.`)
        return {
            proxyAdminAddress: accounts[2],
            adminAddress: '0xeb978AD70211843A0E026d67F362Ce262207C2D9',
            feeAddress: '0xeb978AD70211843A0E026d67F362Ce262207C2D9',
            wNative: '0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd',
            apeFactory: '0x152349604d49c2Af10ADeE94b918b051104a143E',
        }
    } else {
        throw new Error(`No config found for network ${network}.`)
    }
}

module.exports = { getNetworkConfig, isBscMainnet, isDevelopmentNetwork };
