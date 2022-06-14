module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy } = deployments;
  
    const { deployer } = await getNamedAccounts();
  
    const volt = await ethers.getContract("VoltToken");

    await deploy("VoteEscrowVolt", {
      from: deployer,
      args: [volt.address, "VoteEscrowVolt", "veVOLT", "1.0.0"],
      log: true,
      deterministicDeployment: false,
    });
};
  
module.exports.tags = ["VoteEscrowVolt"];
module.exports.dependencies = ["VoltToken"]
