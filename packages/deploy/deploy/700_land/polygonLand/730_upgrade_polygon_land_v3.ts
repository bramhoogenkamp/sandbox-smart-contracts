import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  const {deploy, catchUnknownSigner} = deployments;
  const {deployer, upgradeAdmin} = await getNamedAccounts();
  await catchUnknownSigner(
    deploy('PolygonLand', {
      from: deployer,
      contract:
        '@sandbox-smart-contracts/land/contracts/PolygonLand.sol:PolygonLand',
      proxy: {
        owner: upgradeAdmin,
        proxyContract: 'OpenZeppelinTransparentProxy',
        upgradeIndex: 2,
      },
      log: true,
    })
  );
};
export default func;
func.tags = ['PolygonLand', 'PolygonLandV3', 'PolygonLandV3_deploy', 'L2'];
func.dependencies = ['PolygonLandV2_deploy'];
