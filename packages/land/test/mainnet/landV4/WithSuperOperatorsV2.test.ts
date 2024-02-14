import {expect} from 'chai';
import {loadFixture} from '@nomicfoundation/hardhat-network-helpers';
import {ZeroAddress} from 'ethers';
import {setupLandV4} from './fixtures';

describe('LandV4:SuperOperatorsV2', function () {
  it('should not be a super operator by default', async function () {
    const {LandV4Contract, landAdmin} = await loadFixture(setupLandV4);
    expect(await LandV4Contract.isSuperOperator(landAdmin)).to.be.false;
  });

  it('should be an admin to set super operator', async function () {
    const {LandV4Contract, deployer} = await loadFixture(setupLandV4);
    await expect(
      LandV4Contract.setSuperOperator(deployer, true),
    ).to.be.revertedWith('only admin allowed');
    expect(await LandV4Contract.isSuperOperator(deployer)).to.be.false;
  });

  it('should enable a super operator', async function () {
    const {LandAsAdmin, landAdmin} = await loadFixture(setupLandV4);
    await expect(LandAsAdmin.setSuperOperator(landAdmin.address, true)).not.to
      .be.reverted;
    expect(await LandAsAdmin.isSuperOperator(landAdmin.address)).to.be.true;
  });

  it('should disable a super operator', async function () {
    const {LandAsAdmin, landAdmin} = await loadFixture(setupLandV4);
    await expect(LandAsAdmin.setSuperOperator(landAdmin.address, true)).not.to
      .be.reverted;
    await expect(LandAsAdmin.setSuperOperator(landAdmin.address, false)).not.to
      .be.reverted;
    expect(await LandAsAdmin.isSuperOperator(landAdmin.address)).to.be.false;
  });

  it('should not accept address 0 as super operator', async function () {
    const {LandAsAdmin} = await loadFixture(setupLandV4);
    await expect(
      LandAsAdmin.setSuperOperator(ZeroAddress, false),
    ).to.be.revertedWith('address 0 is not allowed');
    await expect(
      LandAsAdmin.setSuperOperator(ZeroAddress, true),
    ).to.be.revertedWith('address 0 is not allowed');
    expect(await LandAsAdmin.isSuperOperator(ZeroAddress)).to.be.false;
  });

  it('should only be able to disable an enabled super operator', async function () {
    const {LandAsAdmin, landAdmin} = await loadFixture(setupLandV4);
    await expect(LandAsAdmin.setSuperOperator(landAdmin.address, true)).not.to
      .be.reverted;
    expect(await LandAsAdmin.isSuperOperator(landAdmin.address)).to.be.true;
    await expect(
      LandAsAdmin.setSuperOperator(landAdmin.address, true),
    ).to.be.revertedWith('invalid status');
    await expect(LandAsAdmin.setSuperOperator(landAdmin.address, false)).not.to
      .be.reverted;
  });

  it('should only be able to enable a disabled super operator', async function () {
    const {LandAsAdmin, landAdmin} = await loadFixture(setupLandV4);
    expect(await LandAsAdmin.isSuperOperator(landAdmin.address)).to.be.false;
    await expect(
      LandAsAdmin.setSuperOperator(landAdmin.address, false),
    ).to.be.revertedWith('invalid status');
    await expect(LandAsAdmin.setSuperOperator(landAdmin.address, true)).not.to
      .be.reverted;
  });
});
