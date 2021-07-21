
// interface DeployConfig {
//     adminAddress: string;
//     wNative: string;
// }

function getNetworkConfig(network, accounts) {
    if (["bsc", "bsc-fork"].includes(network)) {
        console.log(`Deploying with BSC MAINNET config.`)
        return {
            adminAddress: '0x6c905b4108A87499CEd1E0498721F2B831c6Ab13', // General Admin
            proxyAdmin: '',
            feeAddress: '0x6c905b4108A87499CEd1E0498721F2B831c6Ab13', // Address the fees are paid to
            wNative: '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c',
            apeFactory: '0x0841BD0B734E4F5853f0dD8d7Ea041c241fb0Da6',
        }
    } else if (['testnet', 'testnet-fork'].includes(network)) {
        console.log(`Deploying with BSC testnet config.`)
        return {
            adminAddress: '0xE375D169F8f7bC18a544a6e5e546e63AD7511581',
            proxyAdmin: '',
            feeAddress: '0xE375D169F8f7bC18a544a6e5e546e63AD7511581',
            wNative: '0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd',
            apeFactory: '0x152349604d49c2Af10ADeE94b918b051104a143E',
        }
    } else if (['development'].includes(network)) {
        console.log(`Deploying with development config.`)
        return {
            adminAddress: '0xC9F40d1c8a84b8AeD12A241e7b99682Fb7A3FE84',
            proxyAdmin: '',
            feeAddress: '0xC9F40d1c8a84b8AeD12A241e7b99682Fb7A3FE84',
            wNative: '0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd',
            apeFactory: '0x152349604d49c2Af10ADeE94b918b051104a143E',
        }
    } else {
        throw new Error(`No config found for network ${network}.`)
    }
}

module.exports = { getNetworkConfig };
