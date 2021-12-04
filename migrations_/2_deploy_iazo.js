const IAZO = artifacts.require("IAZO");

const { getNetworkConfig, isDevelopmentNetwork } = require("../deploy-config");

module.exports = async function (deployer, network, accounts) {
  const { proxyAdminAddress, adminAddress, feeAddress, wNative, apeFactory } = getNetworkConfig(network, accounts);

  await deployer.deploy(IAZO);

  console.dir({
    IAZO: IAZO.address,
  });
};
