module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy } = deployments;
  
    const { deployer } = await getNamedAccounts();
  
    await deploy("VoltToken", {
      from: deployer,
      log: true,
      deterministicDeployment: false,
    });
};
  
module.exports.tags = ["VoltToken", "chef"];
