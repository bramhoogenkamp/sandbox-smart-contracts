import hre, { ethers } from "hardhat";

async function createEIP712RevealSignature(
  amounts: number[],
  prevTokenId: number,
  metadataHashes: string[]
): Promise<string> {
  // get named accounts from hardhat
  const { getNamedAccounts } = hre;
  const { backendSigner } = await getNamedAccounts();

  const AssetRevealContract = await ethers.getContract(
    "AssetReveal",
    backendSigner
  );

  const signer = ethers.provider.getSigner(backendSigner);
  const data = {
    types: {
      Reveal: [
        { name: "prevTokenId", type: "uint256" },
        { name: "amounts", type: "uint256[]" },
        { name: "metadataHashes", type: "string[]" },
      ],
    },
    domain: {
      name: "Sandbox Asset Reveal",
      version: "1.0",
      chainId: hre.network.config.chainId,
      verifyingContract: AssetRevealContract.address,
    },
    message: {
      prevTokenId: prevTokenId,
      amounts,
      metadataHashes,
    },
  };

  // @ts-ignore
  const signature = await signer._signTypedData(
    data.domain,
    data.types,
    data.message
  );
  return signature;
}

const createAssetMintSignature = async (
  creator: string,
  tier: number,
  amount: number,
  metadataHash: string
) => {
  const { getNamedAccounts } = hre;
  const { backendSigner } = await getNamedAccounts();
  const signer = ethers.provider.getSigner(backendSigner);

  const AssetCretelContract = await ethers.getContract(
    "AssetCreate",
    backendSigner
  );

  const nonce = await AssetCretelContract.creatorNonces(creator);

  const data = {
    types: {
      Mint: [
        { name: "creator", type: "address" },
        { name: "nonce", type: "uint16" },
        { name: "tier", type: "uint8" },
        { name: "amount", type: "uint256" },
        { name: "metadataHash", type: "string" },
      ],
    },
    domain: {
      name: "Sandbox Asset Create",
      version: "1.0",
      chainId: hre.network.config.chainId,
      verifyingContract: AssetCretelContract.address,
    },
    message: {
      creator,
      nonce,
      tier,
      amount,
      metadataHash,
    },
  };

  const signature = await signer._signTypedData(
    data.domain,
    data.types,
    data.message
  );
  return signature;
};
const createMultipleAssetsMintSignature = async (
  creator: string,
  tiers: number[],
  amounts: number[],
  metadataHashes: string[]
) => {
  const { getNamedAccounts } = hre;
  const { backendSigner } = await getNamedAccounts();
  const signer = ethers.provider.getSigner(backendSigner);

  const AssetCretelContract = await ethers.getContract(
    "AssetCreate",
    backendSigner
  );

  const nonce = await AssetCretelContract.creatorNonces(creator);
  const data = {
    types: {
      Mint: [
        { name: "creator", type: "address" },
        { name: "nonce", type: "uint16" },
        { name: "tiers", type: "uint8[]" },
        { name: "amounts", type: "uint256[]" },
        { name: "metadataHashes", type: "string[]" },
      ],
    },
    domain: {
      name: "Sandbox Asset Create",
      version: "1.0",
      chainId: hre.network.config.chainId,
      verifyingContract: AssetCretelContract.address,
    },
    message: {
      creator,
      nonce,
      tiers,
      amounts,
      metadataHashes,
    },
  };

  const signature = await signer._signTypedData(
    data.domain,
    data.types,
    data.message
  );
  return signature;
};
const createSpecialAssetMintSignature = async () => {};

export {
  createEIP712RevealSignature,
  createAssetMintSignature,
  createMultipleAssetsMintSignature,
  createSpecialAssetMintSignature,
};
