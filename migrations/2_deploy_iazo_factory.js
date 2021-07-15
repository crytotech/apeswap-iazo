const IAZOFactory = artifacts.require("IAZOFactory");
const IAZOSettings = artifacts.require("IAZOSettings");
const IAZOExposer = artifacts.require("IAZOExposer");
const IAZOLiquidityLocker = artifacts.require("IAZOLiquidityLocker");
const { getNetworkConfig } = require("../deploy-config");


// IIAZO_EXPOSER iazoExposer, 
// IIAZOSettings iazoSettings, 
// IIAZOLiquidityLocker iazoliquidityLocker, 
// IWNative wnative

module.exports = async function (deployer, network, accounts) {
  const { adminAddress, wNative, apeFactory } = getNetworkConfig(network, accounts);
  // TODO: transfer ownership
  await deployer.deploy(IAZOExposer);
  // TODO: Add in feeAddress into network config
  await deployer.deploy(IAZOSettings, adminAddress, adminAddress);
  // constructor(address iazoExposer, address apeFactory) {
  //   IAZO_EXPOSER = IAZOExposer(iazoExposer);
  //   APE_FACTORY = IApeFactory(apeFactory);
  // }
  await deployer.deploy(IAZOLiquidityLocker, IAZOExposer.address, apeFactory);
  await deployer.deploy(IAZOFactory, IAZOExposer.address, IAZOSettings.address, IAZOLiquidityLocker.address, wNative );
};
