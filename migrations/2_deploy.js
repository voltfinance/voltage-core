const UniswapV2Factory = artifacts.require("UniswapV2Factory");

const FEE_TO_SETTER_ADDRESS = "0x9Ab1A23a1d2aC3603c73d8d3C1E96B7Fd4e7aA19"

module.exports = function (deployer) {
  deployer.deploy(UniswapV2Factory, FEE_TO_SETTER_ADDRESS);
};
