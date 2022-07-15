module.exports = async function ({ ethers, deployments, getNamedAccounts }) {
  const { deploy } = deployments;

  const { deployer } = await getNamedAccounts();

  // const volt = await ethers.getContract("VoltToken");
  const volt = "0xaB45225DD47f52AC4D836A6c652fe214De10Ac39";
  // const feeDistributor = await ethers.getContract("RewardPool");
  const feeDistributor = deployer;
  const burnPercent  = 7000;

  const { address } = await deploy("PenaltyHandler", {
    from: deployer,
    args: [
        feeDistributor,
        burnPercent,
        volt
    ],
    log: true,
    deterministicDeployment: false,
  });
};

module.exports.tags = ["PenaltyHandler", "chef"];
module.exports.dependencies = ["VoltToken"]
// module.exports.dependencies = ["VoltToken", "RewardPool"]
