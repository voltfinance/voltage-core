const { ethers } = require("hardhat");

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy } = deployments;
  
    const { deployer } = await getNamedAccounts();
  
    // const volt = await ethers.getContract("VoltToken");
    // const voltAddress = volt.address
    const voltAddress = "0xaB45225DD47f52AC4D836A6c652fe214De10Ac39" // TODO: remove dev address
    const veVolt = await ethers.getContract("VotingEscrow")
    const startTime = Math.floor(Date.now() / 1000) - 10 * 24 * 60 * 60 // TODO: change at prod
    const admin = deployer

    await deploy("RewardPool", {
      from: deployer,
      args: [veVolt.address, startTime, voltAddress, admin, admin],
      log: true,
      deterministicDeployment: false,
    });
};
  
module.exports.tags = ["VoteEscrowVolt"];
module.exports.dependencies = ["VoltToken"]
