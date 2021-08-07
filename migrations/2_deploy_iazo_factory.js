const IAZOFactory = artifacts.require("IAZOFactory");
const IAZOSettings = artifacts.require("IAZOSettings");
const IAZOExposer = artifacts.require("IAZOExposer");
const IAZO = artifacts.require("IAZO");
const IAZOLiquidityLocker = artifacts.require("IAZOLiquidityLocker");
const IAZOUpgradeProxy = artifacts.require("IAZOUpgradeProxy");
const { getNetworkConfig } = require("../deploy-config");


module.exports = async function (deployer, network, accounts) {
  const { adminAddress, proxyAdmin, feeAddress, wNative, apeFactory } = getNetworkConfig(network, accounts);
  
  await deployer.deploy(IAZO);
  
  const iazoExposer = await deployer.deploy(IAZOExposer);
  await iazoExposer.transferOwnership(adminAddress);

  await deployer.deploy(IAZOSettings, adminAddress, feeAddress);

  const iazoLiquidityLocker = await deployer.deploy(IAZOLiquidityLocker);
  await iazoLiquidityLocker.transferOwnership(adminAddress);

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
        },
        {
          "internalType": "address",
          "name": "iazoSettings",
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
      apeFactory,
      IAZOSettings.address
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
          "internalType": "contract IIAZO",
          "name": "iazoInitialImplementation",
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
      IAZO.address,
      wNative
    ]
  );

  await deployer.deploy(IAZOUpgradeProxy, proxyAdmin, IAZOFactory.address, abiEncodeDataFactory);

  console.dir({
    IAZOUpgradeProxy: IAZOUpgradeProxy.address,
    IAZOExposer: IAZOExposer.address, 
    IAZOSettings: IAZOSettings.address, 
    IAZOLiquidityLocker: IAZOLiquidityLocker.address, 
    IAZOFactoryProxy: IAZOUpgradeProxy.address,
    IAZO: IAZO.address,
    wNative
  });
};
