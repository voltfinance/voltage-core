module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy } = deployments;
    
    const { deployer } = await getNamedAccounts();

    const volt = await deployments.get("VoltToken");

    await deploy("VoltBar", {
        from: deployer,
        args: [volt.address],
        log: true,
        deterministicDeployment: false
    });
};

module.exports.tags = ["VoltBar"];
module.exports.dependencies = ["VoltToken"];
