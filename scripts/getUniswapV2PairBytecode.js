const UniswapV2Pair = artifacts.require("UniswapV2Pair")

module.exports = async (callback) => {
  console.log("UniswapV2Pair bytecode hash:", (web3.utils.keccak256(UniswapV2Pair.bytecode)).substring(2))
  callback()
}
