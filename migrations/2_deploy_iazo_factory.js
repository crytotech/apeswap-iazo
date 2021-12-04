const IAZOFactory = artifacts.require("IAZOFactory");
const IAZOSettings = artifacts.require("IAZOSettings");
const IAZOSettingsMock = artifacts.require("IAZOSettingsMock");
const IAZOExposer = artifacts.require("IAZOExposer");
const IAZO = artifacts.require("IAZO");
const IAZOLiquidityLocker = artifacts.require("IAZOLiquidityLocker");
const IAZOUpgradeProxy = artifacts.require("IAZOUpgradeProxy");
const IAZOTokenTimelock = artifacts.require("IAZOTokenTimelock");

const { getNetworkConfig, isDevelopmentNetwork } = require("../deploy-config");


module.exports = async function (deployer, network, accounts) {
  const { proxyAdminAddress, adminAddress, feeAddress, wNative, apeFactory } = getNetworkConfig(network, accounts);

  await deployer.deploy(IAZO);

  const iazoExposer = await deployer.deploy(IAZOExposer);
  await iazoExposer.transferOwnership(adminAddress);

  let iazoSettings;
  if (isDevelopmentNetwork(network)) {
    await deployer.deploy(IAZOSettingsMock, adminAddress, feeAddress);
    iazoSettings = await IAZOSettingsMock.at(IAZOSettingsMock.address);
  } else {
    await deployer.deploy(IAZOSettings, adminAddress, feeAddress);
    iazoSettings = await IAZOSettings.at(IAZOSettings.address);
  }

  // Deploy dummy token timelock for verification purposes
  await deployer.deploy(IAZOTokenTimelock);
  await deployer.deploy(IAZOLiquidityLocker);

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
        },
        {
          "internalType": "address",
          "name": "admin",
          "type": "address"
        },
        {
          "internalType": "address",
          "name": "initialTokenTimelockImplementation",
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
      iazoSettings.address,
      adminAddress,
      IAZOTokenTimelock.address
    ]
  );

  await deployer.deploy(IAZOUpgradeProxy, proxyAdminAddress, IAZOLiquidityLocker.address, abiEncodeDataLiquidityLocker);
  const liquidityLockerAddress = IAZOUpgradeProxy.address;

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
        },
        {
          "internalType": "address",
          "name": "admin",
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
      iazoSettings.address,
      liquidityLockerAddress,
      IAZO.address,
      wNative,
      adminAddress
    ]
  );

  await deployer.deploy(IAZOUpgradeProxy, proxyAdminAddress, IAZOFactory.address, abiEncodeDataFactory);

  const factoryAddress = IAZOUpgradeProxy.address;

  console.dir({
    IAZOExposer: IAZOExposer.address,
    IAZOSettings: iazoSettings.address,
    IAZOLiquidityLocker: IAZOLiquidityLocker.address,
    IAZOLiquidityLockerProxy: liquidityLockerAddress,
    IAZOFactory: IAZOFactory.address,
    IAZOFactoryProxy: factoryAddress,
    IAZO: IAZO.address,
    ProxyAdmin: proxyAdminAddress,
    Admin: adminAddress,
    wNative
  });
};
