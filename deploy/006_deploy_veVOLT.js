module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy } = deployments;
  
    const { deployer } = await getNamedAccounts();
  
    // const volt = await ethers.getContract("VoltToken");
    // const voltAddress = volt.address
    const voltAddress = "0xaB45225DD47f52AC4D836A6c652fe214De10Ac39" // dev address
    const admin = deployer

    await deploy("VotingEscrow", {
      from: deployer,
      args: [voltAddress, "Vote Escrow Volt", "veVOLT", admin],
      log: true,
      deterministicDeployment: false,
    });
};
  
module.exports.tags = ["VoteEscrowVolt"];
module.exports.dependencies = ["VoltToken"]
