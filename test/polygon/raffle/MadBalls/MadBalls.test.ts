import {expect} from 'chai';
import {ethers} from 'hardhat';

import {waitFor} from '../../../utils';

import {raffleSignWallet, setupRaffle, assert} from './MadBalls.fixtures';

// eslint-disable-next-line mocha/no-skipped-tests
describe('MadBalls', function () {
  it('should be able to mint with valid signature', async function () {
    const {
      raffleMadBallsContract,
      transferSand,
      setupWave,
      getNamedAccounts,
      hre,
      mint,
    } = await setupRaffle();
    const {deployer} = await getNamedAccounts();
    await transferSand(deployer, '1000');
    await setupWave(raffleMadBallsContract, 20, 5, '10');
    await mint(
      raffleSignWallet,
      deployer,
      0,
      raffleMadBallsContract.address,
      hre.network.config.chainId || 31337,
      '10',
      1
    );

    const transferEvents = await raffleMadBallsContract.queryFilter(
      raffleMadBallsContract.filters.Transfer()
    );

    assert.equal(transferEvents.length, 1);
  });

  // eslint-disable-next-line mocha/no-skipped-tests
  it('should be able to mint 2_023 different tokens', async function () {
    const {
      raffleMadBallsContract,
      transferSand,
      setupWave,
      getNamedAccounts,
      hre,
      mint,
    } = await setupRaffle();
    const {deployer} = await getNamedAccounts();
    await transferSand(deployer, '20000');
    await setupWave(raffleMadBallsContract, 2_023, 2_023, '1');
    const tokens = [];
    for (let i = 0; i < 2_023; i++) {
      if (i % 10 === 0) console.log('minting token', i);
      const receipt = await mint(
        raffleSignWallet,
        deployer,
        i,
        raffleMadBallsContract.address,
        hre.network.config.chainId || 31337,
        '1',
        1
      );
      const transferEvents = await raffleMadBallsContract.queryFilter(
        raffleMadBallsContract.filters.Transfer(),
        receipt.blockNumber
      );
      assert.equal(transferEvents.length, 1);
      assert.exists(transferEvents[0].args);
      if (transferEvents.length > 0 && transferEvents[0].args) {
        const tokenId = transferEvents[0].args.tokenId.toString();
        const exists = tokens.find((token) => token === tokenId);
        assert.notExists(exists);
        tokens.push(tokenId);
      }
    }
  });

  // eslint-disable-next-line mocha/no-skipped-tests
  it('should be able to mint 2_023 different tokens in 3 waves', async function () {
    const {
      raffleMadBallsContract,
      transferSand,
      setupWave,
      getNamedAccounts,
      hre,
      mint,
    } = await setupRaffle();
    const {deployer} = await getNamedAccounts();
    await transferSand(deployer, '2023');
    const waves = [1, 22, 2000];
    const tokens = [];
    let signatureId = 0;
    for (const amount of waves) {
      await setupWave(raffleMadBallsContract, amount, amount, '1');
      for (let i = 0; i < amount; i++) {
        if (signatureId % 10 === 0) console.log('minting token', i);
        signatureId++;
        const receipt = await mint(
          raffleSignWallet,
          deployer,
          signatureId,
          raffleMadBallsContract.address,
          hre.network.config.chainId || 31337,
          '1',
          1
        );
        const transferEvents = await raffleMadBallsContract.queryFilter(
          raffleMadBallsContract.filters.Transfer(),
          receipt.blockNumber
        );
        assert.equal(transferEvents.length, 1);
        assert.exists(transferEvents[0].args);
        if (transferEvents.length > 0 && transferEvents[0].args) {
          const tokenId = transferEvents[0].args.tokenId.toString();
          const exists = tokens.find((token) => token === tokenId);
          assert.notExists(exists);
          tokens.push(tokenId);
        }
      }
    }
    assert.equal(tokens.length, 2023);
  });

  // eslint-disable-next-line mocha/no-skipped-tests
  it.skip('should be able to mint 2_023 different tokens in 3 waves in 3 txs', async function () {
    const {
      raffleMadBallsContract,
      transferSand,
      setupWave,
      getNamedAccounts,
      hre,
      mint,
    } = await setupRaffle();
    const {deployer} = await getNamedAccounts();
    await transferSand(deployer, '20000');
    const waves = [19, 950, 1000];
    const tokens = [];
    let signatureId = 0;
    for (const amount of waves) {
      await setupWave(raffleMadBallsContract, amount, amount, '1');
      signatureId++;
      const receipt = await mint(
        raffleSignWallet,
        deployer,
        signatureId,
        raffleMadBallsContract.address,
        hre.network.config.chainId || 31337,
        amount,
        amount
      );
      const transferEvents = await raffleMadBallsContract.queryFilter(
        raffleMadBallsContract.filters.Transfer(),
        receipt.blockNumber
      );
      assert.equal(transferEvents.length, amount);

      for (const transferEvent of transferEvents) {
        assert.exists(transferEvent.args);
        if (transferEvent.args) {
          const tokenId = transferEvent.args.tokenId.toString();
          const exists = tokens.find((token) => token === tokenId);
          assert.notExists(exists);
          tokens.push(tokenId);
        }
      }
    }
    assert.equal(tokens.length, 2023);
  });

  it('should be able to personalize with valid signature', async function () {
    const {
      raffleMadBallsContract,
      transferSand,
      setupWave,
      getNamedAccounts,
      hre,
      mint,
      personalize,
    } = await setupRaffle();

    const {deployer} = await getNamedAccounts();

    await transferSand(deployer, '1000');
    await setupWave(raffleMadBallsContract, 20, 5, '10');

    await mint(
      raffleSignWallet,
      deployer,
      0,
      raffleMadBallsContract.address,
      hre.network.config.chainId || 31337,
      '10',
      1
    );

    const transferEvents = await raffleMadBallsContract.queryFilter(
      raffleMadBallsContract.filters.Transfer()
    );

    assert.equal(transferEvents.length, 1);
    assert.exists(transferEvents[0].args);

    const tokenId = transferEvents[0]?.args?.tokenId.toString();

    const personalizationMask = 32;

    await personalize(
      raffleSignWallet,
      deployer,
      1,
      hre.network.config.chainId || 31337,
      tokenId,
      personalizationMask
    );

    const personalizeEvents = await raffleMadBallsContract.queryFilter(
      raffleMadBallsContract.filters.Personalized()
    );

    assert.equal(personalizeEvents.length, 1);
    assert.exists(personalizeEvents[0].args);
    assert.equal(
      personalizeEvents[0]?.args?._personalizationMask,
      personalizationMask
    );

    const personalizationOf = await raffleMadBallsContract.personalizationOf(
      tokenId
    );

    assert.equal(personalizationOf, personalizationMask);
  });

  it('should not be able to personalize with invalid signature', async function () {
    const {
      raffleMadBallsContract,
      transferSand,
      setupWave,
      getNamedAccounts,
      hre,
      mint,
      personalizeInvalidSignature,
    } = await setupRaffle();

    const {deployer} = await getNamedAccounts();

    await transferSand(deployer, '1000');
    await setupWave(raffleMadBallsContract, 20, 5, '10');

    await mint(
      raffleSignWallet,
      deployer,
      0,
      raffleMadBallsContract.address,
      hre.network.config.chainId || 31337,
      '10',
      1
    );

    const transferEvents = await raffleMadBallsContract.queryFilter(
      raffleMadBallsContract.filters.Transfer()
    );

    assert.equal(transferEvents.length, 1);
    assert.exists(transferEvents[0].args);

    const tokenId = transferEvents[0]?.args?.tokenId.toString();

    const personalizationMask = 32;

    await expect(
      personalizeInvalidSignature(
        raffleSignWallet,
        deployer,
        1,
        hre.network.config.chainId || 31337,
        tokenId,
        personalizationMask
      )
    ).to.be.revertedWith('Signature failed');
  });

  it('should be able to differentiate a personalized asset', async function () {
    const {
      raffleMadBallsContract,
      transferSand,
      setupWave,
      getNamedAccounts,
      hre,
      mint,
      personalize,
    } = await setupRaffle();

    const {deployer} = await getNamedAccounts();

    await transferSand(deployer, '1000');

    await setupWave(raffleMadBallsContract, 20, 5, '10');

    const receipt1 = await mint(
      raffleSignWallet,
      deployer,
      0,
      raffleMadBallsContract.address,
      hre.network.config.chainId || 31337,
      '10',
      1
    );

    const transferEvents1 = await raffleMadBallsContract.queryFilter(
      raffleMadBallsContract.filters.Transfer(),
      receipt1.blockNumber
    );
    assert.equal(transferEvents1.length, 1);

    const receipt2 = await mint(
      raffleSignWallet,
      deployer,
      1,
      raffleMadBallsContract.address,
      hre.network.config.chainId || 31337,
      '10',
      1
    );

    const transferEvents2 = await raffleMadBallsContract.queryFilter(
      raffleMadBallsContract.filters.Transfer(),
      receipt2.blockNumber
    );
    assert.equal(transferEvents2.length, 1);
    const tokenId2 = transferEvents2[0]?.args?.tokenId.toString();

    const personalizationMask = 16;

    const personalizeReceipt2 = await personalize(
      raffleSignWallet,
      deployer,
      2,
      hre.network.config.chainId || 31337,
      tokenId2,
      personalizationMask
    );

    const allPersonalizeEvents = await raffleMadBallsContract.queryFilter(
      raffleMadBallsContract.filters.Personalized()
    );

    const personalizeEvents2 = await raffleMadBallsContract.queryFilter(
      raffleMadBallsContract.filters.Personalized(),
      personalizeReceipt2.blockNumber
    );

    assert.equal(allPersonalizeEvents.length, 1);
    assert.equal(personalizeEvents2.length, 1);
    assert.equal(
      personalizeEvents2[0]?.args?._personalizationMask,
      personalizationMask
    );
  });

  it('should not be able to personalize twice with the same signature', async function () {
    const {
      raffleMadBallsContract,
      transferSand,
      setupWave,
      getNamedAccounts,
      hre,
      mint,
      personalizeSignature,
    } = await setupRaffle();

    const {deployer} = await getNamedAccounts();

    await transferSand(deployer, '1000');
    await setupWave(raffleMadBallsContract, 20, 5, '10');

    await mint(
      raffleSignWallet,
      deployer,
      0,
      raffleMadBallsContract.address,
      hre.network.config.chainId || 31337,
      '10',
      1
    );

    const transferEvents = await raffleMadBallsContract.queryFilter(
      raffleMadBallsContract.filters.Transfer()
    );

    assert.equal(transferEvents.length, 1);
    assert.exists(transferEvents[0].args);

    const tokenId = transferEvents[0]?.args?.tokenId.toString();

    const personalizationMask = 4;

    const signature = await personalizeSignature(
      raffleSignWallet,
      deployer,
      1,
      raffleMadBallsContract.address,
      hre.network.config.chainId || 31337,
      tokenId,
      personalizationMask
    );

    const contract = raffleMadBallsContract.connect(
      ethers.provider.getSigner(deployer)
    );

    await waitFor(
      contract.personalize(1, signature, tokenId, personalizationMask)
    );

    await expect(
      contract.personalize(1, signature, tokenId, personalizationMask)
    ).to.be.revertedWith('SignatureId already used');
  });
});