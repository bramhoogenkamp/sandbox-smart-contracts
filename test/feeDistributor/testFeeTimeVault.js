const {ethers, getNamedAccounts} = require("@nomiclabs/buidler");
const {BigNumber} = require("@ethersproject/bignumber");
const {expect} = require("local-chai");

describe("FeeTimeVault", function () {
  async function initContracts(lockPeriod, percentages) {
    const accounts = await getNamedAccounts();
    let sandToken = await initContract("Sand", accounts.sandBeneficiary, [
      accounts.sandBeneficiary,
      accounts.sandBeneficiary,
      accounts.sandBeneficiary,
    ]);
    let feeTimeVault = await initContract("FeeTimeVault", accounts.deployer, [lockPeriod, sandToken.address]);
    let feeDist = await initContract("FeeDistributor", accounts.deployer, [
      [accounts.others[0], accounts.others[1], feeTimeVault.address],
      percentages,
    ]);
    await feeTimeVault.connect(ethers.provider.getSigner(accounts.deployer)).setFeeDistributor(feeDist.address);
    return {feeTimeVault, feeDist, sandToken};
  }
  async function initContract(contractName, deployer, params) {
    const ethersFactory = await ethers.getContractFactory(contractName, deployer);
    let contractRef = await ethersFactory.deploy(...params);
    return contractRef;
  }

  async function fundContractWithSand(feeDistContractAdd, sandContract, beneficiary, amount) {
    let tx = await sandContract.connect(ethers.provider.getSigner(beneficiary)).transfer(feeDistContractAdd, amount);
    await tx.wait();
  }
  it("Single deposit with withdraw after lock period", async function () {
    let lockPeriod = 10;
    let percentages = [2000, 2000, 6000];
    let {deployer, sandBeneficiary} = await getNamedAccounts();
    let {feeTimeVault, feeDist, sandToken} = await initContracts(lockPeriod, percentages);
    let amount = BigNumber.from("800000000000000000");
    await fundContractWithSand(feeDist.address, sandToken, sandBeneficiary, amount);
    let tx = await feeTimeVault.connect(ethers.provider.getSigner(deployer)).sync();
    await tx.wait();
    let {timestamp} = await ethers.provider.getBlock("latest");
    let threedaysInSecs = 60 * 60 * 24 * lockPeriod;
    await ethers.provider.send("evm_setNextBlockTimestamp", [timestamp + threedaysInSecs]);
    tx = await feeTimeVault.connect(ethers.provider.getSigner(deployer)).withdraw();
    await tx.wait();
    let balanceAfter = await sandToken.balanceOf(deployer);
    expect(balanceAfter).to.equal(amount.mul(BigNumber.from(percentages[2])).div(BigNumber.from(10000)));
  });
  it("Single deposit with withdraw before lock period should not change token balance", async function () {
    let lockPeriod = 10;
    let percentages = [2000, 2000, 6000];
    let {deployer, sandBeneficiary} = await getNamedAccounts();
    let {feeTimeVault, feeDist, sandToken} = await initContracts(lockPeriod, percentages);
    let amount = BigNumber.from("800000000000000000");
    await fundContractWithSand(feeDist.address, sandToken, sandBeneficiary, amount);
    let tx = await feeTimeVault.connect(ethers.provider.getSigner(deployer)).sync();
    await tx.wait();
    let {timestamp} = await ethers.provider.getBlock("latest");
    let nineDaysInSecs = 60 * 60 * 24 * (lockPeriod - 1);
    await ethers.provider.send("evm_setNextBlockTimestamp", [timestamp + nineDaysInSecs]);
    let sandBalanceBefore = await sandToken.balanceOf(deployer);
    tx = await feeTimeVault.connect(ethers.provider.getSigner(deployer)).withdraw();
    await tx.wait();
    let sandBalanceAfter = await sandToken.balanceOf(deployer);
    expect(sandBalanceBefore).to.equal(sandBalanceAfter);
  });
  it("Deposit that hasn't synced in the same day should be delayed", async function () {
    let lockPeriod = 10;
    let percentages = [2000, 2000, 6000];
    let {deployer, sandBeneficiary} = await getNamedAccounts();
    let {feeTimeVault, feeDist, sandToken} = await initContracts(lockPeriod, percentages);
    let firstAmount = BigNumber.from("800000000000000000");
    let dayInSecs = 60 * 60 * 24;
    await fundContractWithSand(feeDist.address, sandToken, sandBeneficiary, firstAmount);
    let {timestamp} = await ethers.provider.getBlock("latest");
    await ethers.provider.send("evm_setNextBlockTimestamp", [timestamp + dayInSecs]);
    let secondAmount = BigNumber.from("100000000000000000");
    let amount = firstAmount.add(secondAmount);
    await fundContractWithSand(feeDist.address, sandToken, sandBeneficiary, secondAmount);
    let tx = await feeTimeVault.connect(ethers.provider.getSigner(deployer)).sync();
    await tx.wait();
    let accAmount = await feeTimeVault.accumulatedAmountPerDay(1);
    expect(accAmount).to.equal(amount.mul(BigNumber.from(percentages[2])).div(BigNumber.from(10000)));
    timestamp = (await ethers.provider.getBlock("latest")).timestamp;
    await ethers.provider.send("evm_setNextBlockTimestamp", [timestamp + (lockPeriod - 2) * dayInSecs]);
    let sandBalanceBefore = await sandToken.balanceOf(deployer);
    tx = await feeTimeVault.connect(ethers.provider.getSigner(deployer)).withdraw();
    await tx.wait();
    let sandBalanceAfter = await sandToken.balanceOf(deployer);
    expect(sandBalanceBefore).to.equal(sandBalanceAfter);
    timestamp = (await ethers.provider.getBlock("latest")).timestamp;
    await ethers.provider.send("evm_setNextBlockTimestamp", [timestamp + 2 * dayInSecs]);
    tx = await feeTimeVault.connect(ethers.provider.getSigner(deployer)).withdraw();
    await tx.wait();
    timestamp = (await ethers.provider.getBlock("latest")).timestamp;
    let balanceAfter = await sandToken.balanceOf(deployer);
    expect(balanceAfter).to.equal(amount.mul(BigNumber.from(percentages[2])).div(BigNumber.from(10000)));
  });
  it("First deposit syncs before the lock period, second after the lock period", async function () {
    let lockPeriod = 4;
    let percentages = [2000, 2000, 6000];
    let {deployer, sandBeneficiary} = await getNamedAccounts();
    let {feeTimeVault, feeDist, sandToken} = await initContracts(lockPeriod, percentages);
    let amount1 = BigNumber.from("800000000000000000");
    await fundContractWithSand(feeDist.address, sandToken, sandBeneficiary, amount1);
    let tx = await feeTimeVault.connect(ethers.provider.getSigner(deployer)).sync();
    await tx.wait();
    let {timestamp} = await ethers.provider.getBlock("latest");
    let threedaysInSecs = 60 * 60 * 24 * (lockPeriod - 1);
    await ethers.provider.send("evm_setNextBlockTimestamp", [timestamp + threedaysInSecs]);
    let amount2 = BigNumber.from("700000000000000000");
    await fundContractWithSand(feeDist.address, sandToken, sandBeneficiary, amount2);
    let lockPeriodInSecs = 60 * 60 * 24 * lockPeriod;
    await ethers.provider.send("evm_setNextBlockTimestamp", [timestamp + lockPeriodInSecs]);
    tx = await feeTimeVault.connect(ethers.provider.getSigner(deployer)).sync();
    await tx.wait();
    tx = await feeTimeVault.connect(ethers.provider.getSigner(deployer)).withdraw();
    await tx.wait();
    let balanceAfter = await sandToken.balanceOf(deployer);
    expect(balanceAfter).to.equal(amount1.mul(BigNumber.from(percentages[2])).div(BigNumber.from(10000)));
  });
  it("Funds should be withdrawn only once", async function () {
    let lockPeriod = 4;
    let percentages = [2000, 2000, 6000];
    let {deployer, sandBeneficiary} = await getNamedAccounts();
    let {feeTimeVault, feeDist, sandToken} = await initContracts(lockPeriod, percentages);
    let amount1 = BigNumber.from("1000000000000000000");
    await fundContractWithSand(feeDist.address, sandToken, sandBeneficiary, amount1);
    let tx = await feeTimeVault.connect(ethers.provider.getSigner(deployer)).sync();
    await tx.wait();
    let {timestamp} = await ethers.provider.getBlock("latest");
    let lockPeriodInSecs = 60 * 60 * 24 * lockPeriod;
    await ethers.provider.send("evm_setNextBlockTimestamp", [timestamp + lockPeriodInSecs]);
    tx = await feeTimeVault.connect(ethers.provider.getSigner(deployer)).withdraw();
    await tx.wait();
    let balanceAfter1 = await sandToken.balanceOf(deployer);
    expect(balanceAfter1).to.equal(amount1.mul(BigNumber.from(percentages[2])).div(BigNumber.from(10000)));
    tx = await feeTimeVault.connect(ethers.provider.getSigner(deployer)).withdraw();
    await tx.wait();
    let balanceAfter2 = await sandToken.balanceOf(deployer);
    expect(balanceAfter2).to.equal(balanceAfter1);
  });
  it("Funds should be synced only once", async function () {
    let lockPeriod = 4;
    let percentages = [2000, 2000, 6000];
    let {deployer, sandBeneficiary} = await getNamedAccounts();
    let {feeTimeVault, feeDist, sandToken} = await initContracts(lockPeriod, percentages);
    let amount1 = BigNumber.from("1000000000000000000");
    await fundContractWithSand(feeDist.address, sandToken, sandBeneficiary, amount1);
    let tx = await feeTimeVault.connect(ethers.provider.getSigner(deployer)).sync();
    await tx.wait();
    let b1 = await feeTimeVault.accumulatedAmountPerDay(0);
    let {timestamp} = await ethers.provider.getBlock("latest");
    let oneDayInSecs = 60 * 60 * 24 * 1;
    await ethers.provider.send("evm_setNextBlockTimestamp", [timestamp + oneDayInSecs]);
    tx = await feeTimeVault.connect(ethers.provider.getSigner(deployer)).sync();
    await tx.wait();
    let b2 = await feeTimeVault.accumulatedAmountPerDay(1);
    expect(b1).to.equal(b2);
  });
});
