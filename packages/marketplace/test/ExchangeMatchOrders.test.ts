import {expect} from 'chai';
import {deployFixtures} from './fixtures.ts';
import {loadFixture} from '@nomicfoundation/hardhat-network-helpers';
import {AssetERC20, AssetERC721, AssetERC1155} from './utils/assets.ts';

import {hashKey, OrderDefault, signOrder} from './utils/order.ts';
import {ZeroAddress, AbiCoder} from 'ethers';

describe('Exchange MatchOrders', function () {
  let ExchangeContractAsUser,
    OrderValidatorAsAdmin,
    ERC20Contract,
    ERC20Contract2,
    ERC721Contract,
    ERC1155Contract,
    protocolFeeSecondary,
    defaultFeeReceiver,
    maker,
    taker,
    makerAsset,
    takerAsset,
    orderLeft,
    orderRight,
    makerSig,
    takerSig;

  beforeEach(async function () {
    ({
      ExchangeContractAsUser,
      OrderValidatorAsAdmin,
      ERC20Contract,
      ERC20Contract2,
      ERC721Contract,
      ERC1155Contract,
      protocolFeeSecondary,
      defaultFeeReceiver,
      user1: maker,
      user2: taker,
    } = await loadFixture(deployFixtures));
  });

  describe('between ERC20-ERC20 token', function () {
    beforeEach(async function () {
      await ERC20Contract.mint(maker.address, 123000000);
      await ERC20Contract.connect(maker).approve(
        await ExchangeContractAsUser.getAddress(),
        123000000
      );

      await ERC20Contract2.mint(taker.address, 456000000);
      await ERC20Contract2.connect(taker).approve(
        await ExchangeContractAsUser.getAddress(),
        456000000
      );
      makerAsset = await AssetERC20(ERC20Contract, 123000000);
      takerAsset = await AssetERC20(ERC20Contract2, 456000000);
      orderLeft = await OrderDefault(
        maker,
        makerAsset,
        ZeroAddress,
        takerAsset,
        1,
        0,
        0
      );
      orderRight = await OrderDefault(
        taker,
        takerAsset,
        ZeroAddress,
        makerAsset,
        1,
        0,
        0
      );

      makerSig = await signOrder(orderLeft, maker, OrderValidatorAsAdmin);
      takerSig = await signOrder(orderRight, taker, OrderValidatorAsAdmin);
    });

    it('should execute a complete match order between ERC20 tokens', async function () {
      await ExchangeContractAsUser.matchOrders([
        {
          orderLeft,
          signatureLeft: makerSig,
          orderRight,
          signatureRight: takerSig,
        },
      ]);

      expect(await ERC20Contract.balanceOf(maker)).to.be.equal(0);
      expect(await ERC20Contract.balanceOf(taker)).to.be.equal(123000000);
      expect(await ERC20Contract2.balanceOf(maker)).to.be.equal(456000000);
      expect(await ERC20Contract2.balanceOf(taker)).to.be.equal(0);
    });

    it('should partially fill orders using matchOrders between ERC20 tokens', async function () {
      const makerAssetForLeftOrder = await AssetERC20(ERC20Contract, 123000000);
      const takerAssetForLeftOrder = await AssetERC20(
        ERC20Contract2,
        456000000
      );
      const takerAssetForRightOrder = await AssetERC20(
        ERC20Contract2,
        228000000
      );
      const makerAssetForRightOrder = await AssetERC20(ERC20Contract, 61500000);

      orderLeft = await OrderDefault(
        maker,
        makerAssetForLeftOrder,
        ZeroAddress,
        takerAssetForLeftOrder,
        1,
        0,
        0
      );
      orderRight = await OrderDefault(
        taker,
        takerAssetForRightOrder,
        ZeroAddress,
        makerAssetForRightOrder,
        1,
        0,
        0
      );

      makerSig = await signOrder(orderLeft, maker, OrderValidatorAsAdmin);
      takerSig = await signOrder(orderRight, taker, OrderValidatorAsAdmin);
      expect(
        await ExchangeContractAsUser.fills(hashKey(orderLeft))
      ).to.be.equal(0);
      expect(
        await ExchangeContractAsUser.fills(hashKey(orderRight))
      ).to.be.equal(0);

      await ExchangeContractAsUser.matchOrders([
        {
          orderLeft,
          signatureLeft: makerSig,
          orderRight,
          signatureRight: takerSig,
        },
      ]);

      expect(
        await ExchangeContractAsUser.fills(hashKey(orderLeft))
      ).to.be.equal(228000000);
      expect(
        await ExchangeContractAsUser.fills(hashKey(orderRight))
      ).to.be.equal(61500000);
      expect(await ERC20Contract.balanceOf(maker)).to.be.equal(61500000);
      expect(await ERC20Contract.balanceOf(taker)).to.be.equal(61500000);
      expect(await ERC20Contract2.balanceOf(maker)).to.be.equal(228000000);
      expect(await ERC20Contract2.balanceOf(taker)).to.be.equal(228000000);
    });

    it('should fully fill a order using partial matches between ERC20 tokens', async function () {
      const makerAssetForLeftOrder = await AssetERC20(ERC20Contract, 123000000);
      const takerAssetForLeftOrder = await AssetERC20(
        ERC20Contract2,
        456000000
      );
      const takerAssetForRightOrder = await AssetERC20(
        ERC20Contract2,
        228000000
      );
      const makerAssetForRightOrder = await AssetERC20(ERC20Contract, 61500000);

      orderLeft = await OrderDefault(
        maker,
        makerAssetForLeftOrder,
        ZeroAddress,
        takerAssetForLeftOrder,
        1,
        0,
        0
      );
      const rightOrderForFirstMatch = await OrderDefault(
        taker,
        takerAssetForRightOrder,
        ZeroAddress,
        makerAssetForRightOrder,
        1,
        0,
        0
      );

      makerSig = await signOrder(orderLeft, maker, OrderValidatorAsAdmin);
      const takerSigForFirstMatch = await signOrder(
        rightOrderForFirstMatch,
        taker,
        OrderValidatorAsAdmin
      );
      expect(
        await ExchangeContractAsUser.fills(hashKey(orderLeft))
      ).to.be.equal(0);
      expect(
        await ExchangeContractAsUser.fills(hashKey(rightOrderForFirstMatch))
      ).to.be.equal(0);

      await ExchangeContractAsUser.matchOrders([
        {
          orderLeft,
          signatureLeft: makerSig,
          orderRight: rightOrderForFirstMatch,
          signatureRight: takerSigForFirstMatch,
        },
      ]);

      expect(
        await ExchangeContractAsUser.fills(hashKey(orderLeft))
      ).to.be.equal(228000000);
      expect(
        await ExchangeContractAsUser.fills(hashKey(rightOrderForFirstMatch))
      ).to.be.equal(61500000);
      expect(await ERC20Contract.balanceOf(maker)).to.be.equal(61500000);
      expect(await ERC20Contract.balanceOf(taker)).to.be.equal(61500000);
      expect(await ERC20Contract2.balanceOf(maker)).to.be.equal(228000000);
      expect(await ERC20Contract2.balanceOf(taker)).to.be.equal(228000000);

      const rightOrderForSecondMatch = await OrderDefault(
        taker,
        takerAssetForRightOrder,
        ZeroAddress,
        makerAssetForRightOrder,
        2,
        0,
        0
      );
      const takerSigForSecondMatch = await signOrder(
        rightOrderForSecondMatch,
        taker,
        OrderValidatorAsAdmin
      );

      await ExchangeContractAsUser.matchOrders([
        {
          orderLeft,
          signatureLeft: makerSig,
          orderRight: rightOrderForSecondMatch,
          signatureRight: takerSigForSecondMatch,
        },
      ]);

      expect(
        await ExchangeContractAsUser.fills(hashKey(orderLeft))
      ).to.be.equal(456000000);
      expect(
        await ExchangeContractAsUser.fills(hashKey(rightOrderForSecondMatch))
      ).to.be.equal(61500000);
      expect(await ERC20Contract.balanceOf(maker)).to.be.equal(0);
      expect(await ERC20Contract.balanceOf(taker)).to.be.equal(123000000);
      expect(await ERC20Contract2.balanceOf(maker)).to.be.equal(456000000);
      expect(await ERC20Contract2.balanceOf(taker)).to.be.equal(0);
    });
  });

  describe('between ERC20-ERC721 token', function () {
    beforeEach(async function () {
      await ERC20Contract.mint(maker.address, 10000000000);
      await ERC20Contract.connect(maker).approve(
        await ExchangeContractAsUser.getAddress(),
        10000000000
      );
      await ERC721Contract.mint(taker.address, 1);
      await ERC721Contract.connect(taker).approve(
        await ExchangeContractAsUser.getAddress(),
        1
      );

      makerAsset = await AssetERC20(ERC20Contract, 10000000000);
      takerAsset = await AssetERC721(ERC721Contract, 1);
      orderLeft = await OrderDefault(
        maker,
        makerAsset,
        ZeroAddress,
        takerAsset,
        1,
        0,
        0
      );
      orderRight = await OrderDefault(
        taker,
        takerAsset,
        ZeroAddress,
        makerAsset,
        1,
        0,
        0
      );
      makerSig = await signOrder(orderLeft, maker, OrderValidatorAsAdmin);
      takerSig = await signOrder(orderRight, taker, OrderValidatorAsAdmin);
    });

    it('should execute a complete match order between ERC20 and ERC721 tokens', async function () {
      expect(
        await ExchangeContractAsUser.fills(hashKey(orderLeft))
      ).to.be.equal(0);
      expect(
        await ExchangeContractAsUser.fills(hashKey(orderRight))
      ).to.be.equal(0);

      await ExchangeContractAsUser.matchOrders([
        {
          orderLeft, // ERC20 order
          signatureLeft: makerSig,
          orderRight, // ERC721 order
          signatureRight: takerSig,
        },
      ]);

      expect(
        await ExchangeContractAsUser.fills(hashKey(orderLeft))
      ).to.be.equal(1);
      expect(
        await ExchangeContractAsUser.fills(hashKey(orderRight))
      ).to.be.equal(10000000000);
      expect(await ERC721Contract.ownerOf(1)).to.be.equal(maker.address);
      expect(await ERC20Contract.balanceOf(taker.address)).to.be.equal(
        9750000000 // 10000000000 - protocolFee
      );

      // check protocol fee -> 250 * 10000000000 / 10000 = 250000000
      expect(
        await ERC20Contract.balanceOf(defaultFeeReceiver.address)
      ).to.be.equal(
        (Number(protocolFeeSecondary) * Number(makerAsset.value)) / 10000
      );
    });

    it('should execute a complete match order between ERC721 and ERC20 tokens', async function () {
      expect(
        await ExchangeContractAsUser.fills(hashKey(orderLeft))
      ).to.be.equal(0);
      expect(
        await ExchangeContractAsUser.fills(hashKey(orderRight))
      ).to.be.equal(0);

      await ExchangeContractAsUser.matchOrders([
        {
          orderRight, // ERC721 order
          signatureRight: takerSig,
          orderLeft, // ERC20 order
          signatureLeft: makerSig,
        },
      ]);

      expect(
        await ExchangeContractAsUser.fills(hashKey(orderLeft))
      ).to.be.equal(1);
      expect(
        await ExchangeContractAsUser.fills(hashKey(orderRight))
      ).to.be.equal(10000000000);
      expect(await ERC721Contract.ownerOf(1)).to.be.equal(maker.address);
      expect(await ERC20Contract.balanceOf(taker.address)).to.be.equal(
        9750000000 // 10000000000 - protocolFee
      );
    });

    it('should not execute match order with non-one value for ERC721 asset class', async function () {
      takerAsset = {
        assetType: {
          assetClass: '0x2', // ERC721_ASSET_CLASS = '0x2',
          data: AbiCoder.defaultAbiCoder().encode(
            ['address', 'uint256'],
            [await ERC721Contract.getAddress(), 1]
          ),
        },
        value: 2,
      };
      orderLeft = await OrderDefault(
        maker,
        makerAsset,
        ZeroAddress,
        takerAsset,
        1,
        0,
        0
      );
      orderRight = await OrderDefault(
        taker,
        takerAsset,
        ZeroAddress,
        makerAsset,
        1,
        0,
        0
      );
      makerSig = await signOrder(orderLeft, maker, OrderValidatorAsAdmin);
      takerSig = await signOrder(orderRight, taker, OrderValidatorAsAdmin);

      expect(
        await ExchangeContractAsUser.fills(hashKey(orderLeft))
      ).to.be.equal(0);
      expect(
        await ExchangeContractAsUser.fills(hashKey(orderRight))
      ).to.be.equal(0);

      await expect(
        ExchangeContractAsUser.matchOrders([
          {
            orderLeft,
            signatureLeft: makerSig,
            orderRight,
            signatureRight: takerSig,
          },
        ])
      ).to.be.revertedWith('erc721 value error');
    });
  });

  describe('between ERC20-ERC1155 token', function () {
    beforeEach(async function () {
      await ERC20Contract.mint(maker.address, 10000000000);
      await ERC20Contract.connect(maker).approve(
        await ExchangeContractAsUser.getAddress(),
        10000000000
      );

      await ERC1155Contract.mint(taker.address, 1, 10);
      await ERC1155Contract.connect(taker).setApprovalForAll(
        await ExchangeContractAsUser.getAddress(),
        true
      );

      makerAsset = await AssetERC20(ERC20Contract, 10000000000);
      takerAsset = await AssetERC1155(ERC1155Contract, 1, 10);

      orderLeft = await OrderDefault(
        maker,
        makerAsset,
        ZeroAddress,
        takerAsset,
        1,
        0,
        0
      );
      orderRight = await OrderDefault(
        taker,
        takerAsset,
        ZeroAddress,
        makerAsset,
        1,
        0,
        0
      );
      makerSig = await signOrder(orderLeft, maker, OrderValidatorAsAdmin);
      takerSig = await signOrder(orderRight, taker, OrderValidatorAsAdmin);
    });

    it('should execute a complete match order between ERC20 and ERC1155 tokens', async function () {
      expect(
        await ExchangeContractAsUser.fills(hashKey(orderLeft))
      ).to.be.equal(0);
      expect(
        await ExchangeContractAsUser.fills(hashKey(orderRight))
      ).to.be.equal(0);

      await ExchangeContractAsUser.matchOrders([
        {
          orderLeft, // ERC20 order
          signatureLeft: makerSig,
          orderRight, // ERC1155 order
          signatureRight: takerSig,
        },
      ]);

      expect(
        await ExchangeContractAsUser.fills(hashKey(orderLeft))
      ).to.be.equal(10);
      expect(
        await ExchangeContractAsUser.fills(hashKey(orderRight))
      ).to.be.equal(10000000000);
      expect(await ERC1155Contract.balanceOf(maker.address, 1)).to.be.equal(10);
      expect(await ERC1155Contract.balanceOf(taker.address, 1)).to.be.equal(0);
      expect(await ERC20Contract.balanceOf(maker.address)).to.be.equal(0);
      expect(await ERC20Contract.balanceOf(taker.address)).to.be.equal(
        9750000000 // 10000000000 - protocolFee
      );

      // check protocol fee -> 250 * 10000000000 / 10000 = 250000000
      expect(
        await ERC20Contract.balanceOf(defaultFeeReceiver.address)
      ).to.be.equal(
        (Number(protocolFeeSecondary) * Number(makerAsset.value)) / 10000
      );
    });

    it('should execute a complete match order between ERC1155 and ERC20 tokens', async function () {
      expect(
        await ExchangeContractAsUser.fills(hashKey(orderLeft))
      ).to.be.equal(0);
      expect(
        await ExchangeContractAsUser.fills(hashKey(orderRight))
      ).to.be.equal(0);

      await ExchangeContractAsUser.matchOrders([
        {
          orderRight, // ERC1155 order
          signatureRight: takerSig,
          orderLeft, // ERC20 order
          signatureLeft: makerSig,
        },
      ]);

      expect(
        await ExchangeContractAsUser.fills(hashKey(orderLeft))
      ).to.be.equal(10);
      expect(
        await ExchangeContractAsUser.fills(hashKey(orderRight))
      ).to.be.equal(10000000000);
      expect(await ERC1155Contract.balanceOf(maker.address, 1)).to.be.equal(10);
      expect(await ERC1155Contract.balanceOf(taker.address, 1)).to.be.equal(0);
      expect(await ERC20Contract.balanceOf(maker.address)).to.be.equal(0);
      expect(await ERC20Contract.balanceOf(taker.address)).to.be.equal(
        9750000000 // 10000000000 - protocolFee
      );
    });

    it('should partially fill orders using matchOrders between ERC20 and ERC1155 tokens', async function () {
      const makerAssetForLeftOrder = await AssetERC20(
        ERC20Contract,
        10000000000
      );
      const takerAssetForLeftOrder = await AssetERC1155(ERC1155Contract, 1, 10);
      const takerAssetForRightOrder = await AssetERC1155(ERC1155Contract, 1, 5);
      const makerAssetForRightOrder = await AssetERC20(
        ERC20Contract,
        5000000000
      );
      orderLeft = await OrderDefault(
        maker,
        makerAssetForLeftOrder,
        ZeroAddress,
        takerAssetForLeftOrder,
        1,
        0,
        0
      );
      orderRight = await OrderDefault(
        taker,
        takerAssetForRightOrder,
        ZeroAddress,
        makerAssetForRightOrder,
        1,
        0,
        0
      );
      makerSig = await signOrder(orderLeft, maker, OrderValidatorAsAdmin);
      takerSig = await signOrder(orderRight, taker, OrderValidatorAsAdmin);
      expect(
        await ExchangeContractAsUser.fills(hashKey(orderLeft))
      ).to.be.equal(0);
      expect(
        await ExchangeContractAsUser.fills(hashKey(orderRight))
      ).to.be.equal(0);

      await ExchangeContractAsUser.matchOrders([
        {
          orderLeft,
          signatureLeft: makerSig,
          orderRight,
          signatureRight: takerSig,
        },
      ]);

      expect(
        await ExchangeContractAsUser.fills(hashKey(orderLeft))
      ).to.be.equal(5);
      expect(
        await ExchangeContractAsUser.fills(hashKey(orderRight))
      ).to.be.equal(5000000000);
      expect(await ERC20Contract.balanceOf(maker.address)).to.be.equal(
        5000000000
      );
      expect(await ERC20Contract.balanceOf(taker.address)).to.be.equal(
        4875000000 // 5000000000 - protocolFee
      );
      expect(await ERC1155Contract.balanceOf(maker.address, 1)).to.be.equal(5);
      expect(await ERC1155Contract.balanceOf(taker.address, 1)).to.be.equal(5);
    });

    it('should fully fill a order using partial matches between ERC20 and ERC1155 tokens', async function () {
      const makerAssetForLeftOrder = await AssetERC20(
        ERC20Contract,
        10000000000
      );
      const takerAssetForLeftOrder = await AssetERC1155(ERC1155Contract, 1, 10);
      const takerAssetForRightOrder = await AssetERC1155(ERC1155Contract, 1, 5);
      const makerAssetForRightOrder = await AssetERC20(
        ERC20Contract,
        5000000000
      );

      orderLeft = await OrderDefault(
        maker,
        makerAssetForLeftOrder,
        ZeroAddress,
        takerAssetForLeftOrder,
        1,
        0,
        0
      );
      const rightOrderForFirstMatch = await OrderDefault(
        taker,
        takerAssetForRightOrder,
        ZeroAddress,
        makerAssetForRightOrder,
        1,
        0,
        0
      );

      makerSig = await signOrder(orderLeft, maker, OrderValidatorAsAdmin);
      const takerSigForFirstMatch = await signOrder(
        rightOrderForFirstMatch,
        taker,
        OrderValidatorAsAdmin
      );

      expect(
        await ExchangeContractAsUser.fills(hashKey(orderLeft))
      ).to.be.equal(0);
      expect(
        await ExchangeContractAsUser.fills(hashKey(rightOrderForFirstMatch))
      ).to.be.equal(0);

      await ExchangeContractAsUser.matchOrders([
        {
          orderLeft,
          signatureLeft: makerSig,
          orderRight: rightOrderForFirstMatch,
          signatureRight: takerSigForFirstMatch,
        },
      ]);

      expect(
        await ExchangeContractAsUser.fills(hashKey(orderLeft))
      ).to.be.equal(5);
      expect(
        await ExchangeContractAsUser.fills(hashKey(rightOrderForFirstMatch))
      ).to.be.equal(5000000000);
      expect(await ERC1155Contract.balanceOf(maker.address, 1)).to.be.equal(5);
      expect(await ERC1155Contract.balanceOf(taker.address, 1)).to.be.equal(5);
      expect(await ERC20Contract.balanceOf(maker.address)).to.be.equal(
        5000000000
      );
      expect(await ERC20Contract.balanceOf(taker.address)).to.be.equal(
        4875000000 // 5000000000 - protocolFee
      );
      const rightOrderForSecondMatch = await OrderDefault(
        taker,
        takerAssetForRightOrder,
        ZeroAddress,
        makerAssetForRightOrder,
        2,
        0,
        0
      );
      const takerSigForSecondMatch = await signOrder(
        rightOrderForSecondMatch,
        taker,
        OrderValidatorAsAdmin
      );
      await ExchangeContractAsUser.matchOrders([
        {
          orderLeft,
          signatureLeft: makerSig,
          orderRight: rightOrderForSecondMatch,
          signatureRight: takerSigForSecondMatch,
        },
      ]);
      expect(
        await ExchangeContractAsUser.fills(hashKey(orderLeft))
      ).to.be.equal(10);
      expect(
        await ExchangeContractAsUser.fills(hashKey(rightOrderForSecondMatch))
      ).to.be.equal(5000000000);
      expect(await ERC1155Contract.balanceOf(maker.address, 1)).to.be.equal(10);
      expect(await ERC1155Contract.balanceOf(taker.address, 1)).to.be.equal(0);
      expect(await ERC20Contract.balanceOf(maker.address)).to.be.equal(0);
      expect(await ERC20Contract.balanceOf(taker.address)).to.be.equal(
        9750000000 // 10000000000 - protocolFee
      );
    });
  });

  it('should not execute match order for already matched orders', async function () {
    await ERC20Contract.mint(maker.address, 123000000);
    await ERC20Contract.connect(maker).approve(
      await ExchangeContractAsUser.getAddress(),
      123000000
    );

    await ERC20Contract2.mint(taker.address, 456000000);
    await ERC20Contract2.connect(taker).approve(
      await ExchangeContractAsUser.getAddress(),
      456000000
    );
    makerAsset = await AssetERC20(ERC20Contract, 123000000);
    takerAsset = await AssetERC20(ERC20Contract2, 456000000);
    orderLeft = await OrderDefault(
      maker,
      makerAsset,
      ZeroAddress,
      takerAsset,
      1,
      0,
      0
    );
    orderRight = await OrderDefault(
      taker,
      takerAsset,
      ZeroAddress,
      makerAsset,
      1,
      0,
      0
    );

    makerSig = await signOrder(orderLeft, maker, OrderValidatorAsAdmin);
    takerSig = await signOrder(orderRight, taker, OrderValidatorAsAdmin);

    await ExchangeContractAsUser.matchOrders([
      {
        orderLeft,
        signatureLeft: makerSig,
        orderRight,
        signatureRight: takerSig,
      },
    ]);

    expect(await ERC20Contract.balanceOf(maker)).to.be.equal(0);
    expect(await ERC20Contract.balanceOf(taker)).to.be.equal(123000000);
    expect(await ERC20Contract2.balanceOf(maker)).to.be.equal(456000000);
    expect(await ERC20Contract2.balanceOf(taker)).to.be.equal(0);

    await expect(
      ExchangeContractAsUser.matchOrders([
        {
          orderLeft,
          signatureLeft: makerSig,
          orderRight,
          signatureRight: takerSig,
        },
      ])
    ).to.be.revertedWith('nothing to fill');
  });
});
