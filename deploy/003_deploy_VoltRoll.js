module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy } = deployments;
    
    const { deployer } = await getNamedAccounts();

    const oldRouter = '0xFB76e9E7d88E308aB530330eD90e84a952570319'
    const newRouter = '0xE3F85aAd0c8DD7337427B9dF5d0fB741d65EEEB5'

    await deploy("VoltRoll", {
        from: deployer,
        args: [oldRouter, newRouter],
        log: true,
        deterministicDeployment: false
    });
};

module.exports.tags = ["VoltRoll"];
