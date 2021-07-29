const IAZOFactory = artifacts.require("IAZOFactory");
const IAZOSettings = artifacts.require("IAZOSettings");
const IAZOExposer = artifacts.require("IAZOExposer");
const IAZO = artifacts.require("IAZO");
const IAZOLiquidityLocker = artifacts.require("IAZOLiquidityLocker");
const IAZOUpgradeProxy = artifacts.require("IAZOUpgradeProxy");
const { getNetworkConfig } = require("../deploy-config");


// IIAZO_EXPOSER iazoExposer, 
// IIAZOSettings iazoSettings, 
// IIAZOLiquidityLocker iazoliquidityLocker, 
// IWNative wnative

module.exports = async function (deployer, network, accounts) {
  const { adminAddress, proxyAdmin, feeAddress, wNative, apeFactory } = getNetworkConfig(network, accounts);
  
  await deployer.deploy(IAZO);
  
  await deployer.deploy(IAZOExposer);
  IAZOExposer.transferOwnership(adminAddress);

  await deployer.deploy(IAZOSettings, adminAddress, feeAddress);
  // constructor(address iazoExposer, address apeFactory) {
  //   IAZO_EXPOSER = IAZOExposer(iazoExposer);
  //   APE_FACTORY = IApeFactory(apeFactory);
  // }
  await deployer.deploy(IAZOLiquidityLocker);
  IAZOLiquidityLocker.transferOwnership(adminAddress);

  const abiEncodeDataLiquidityLocker = web3.eth.abi.encodeFunctionCall(
    {
      "inputs": [
        {
          "internalType": "address",
          "name": "iazoExposer",
          "type": "address"
        },
        {
          "internalType": "address",
          "name": "apeFactory",
          "type": "address"
        }
      ],
      "name": "initialize",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    [
      IAZOExposer.address,
      apeFactory
    ]
  );

  await deployer.deploy(IAZOUpgradeProxy, proxyAdmin, IAZOLiquidityLocker.address, abiEncodeDataLiquidityLocker);

  // Deployment of Factory and FactoryProxy
  await deployer.deploy(IAZOFactory);

  const abiEncodeDataFactory = web3.eth.abi.encodeFunctionCall(
    {
      "inputs": [
        {
          "internalType": "contract IIAZO_EXPOSER",
          "name": "iazoExposer",
          "type": "address"
        },
        {
          "internalType": "contract IIAZOSettings",
          "name": "iazoSettings",
          "type": "address"
        },
        {
          "internalType": "contract IIAZOLiquidityLocker",
          "name": "iazoliquidityLocker",
          "type": "address"
        },
        {
          "internalType": "contract IWNative",
          "name": "wnative",
          "type": "address"
        }
      ],
      "name": "initialize",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    [
      IAZOExposer.address,
      IAZOSettings.address,
      IAZOLiquidityLocker.address,
      wNative
    ]
  );

  await deployer.deploy(IAZOUpgradeProxy, proxyAdmin, IAZOFactory.address, abiEncodeDataFactory);

  console.log("IAZOExposer: ", IAZOExposer.address, "IAZOSettings: ", IAZOSettings.address, "IAZOLiquidityLocker: ", IAZOLiquidityLocker.address, "IAZOFactoryProxy: ", IAZOUpgradeProxy.address);
};
