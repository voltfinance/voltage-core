module.exports = async function ({ ethers, getNamedAccounts, deployments }) {
  const { deploy } = deployments;

  const { deployer } = await getNamedAccounts();

  const factory = '0x1998E4b0F1F922367d8Ec20600ea2b86df55f34E'
  const wfuse = '0x0BE9e53fd7EDaC9F859882AfdDa116645287C629'

  const bar = await ethers.getContract("VoltBar");
  const volt = await ethers.getContract("VoltToken");

  await deploy("VoltMakerV2", {
    from: deployer,
    args: [factory, bar.address, volt.address, wfuse],
    log: true,
    deterministicDeployment: false,
  });
};

module.exports.tags = ["VoltMakerV2"];
module.exports.dependencies = [
  "VoltBar",
  "VoltToken",
];
