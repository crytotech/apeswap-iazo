const Banana = artifacts.require("Banana");
const WBNB = artifacts.require("WBNB");

module.exports = function (deployer) {
  deployer.deploy(WBNB);
  deployer.deploy(Banana);
};
