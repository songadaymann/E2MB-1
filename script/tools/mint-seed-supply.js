#!/usr/bin/env node
import { ethers } from "ethers";

async function main() {
  const {
    SEPOLIA_RPC_URL,
    PRIVATE_KEY,
    MSONG_ADDRESS = process.env.MSONG_ADDRESS,
    TOKEN_MINT_TARGET = "5",
  } = process.env;

  if (!SEPOLIA_RPC_URL || !PRIVATE_KEY || !MSONG_ADDRESS) {
    throw new Error("Missing SEPOLIA_RPC_URL, PRIVATE_KEY, or MSONG_ADDRESS env vars.");
  }

  const provider = new ethers.JsonRpcProvider(SEPOLIA_RPC_URL);
  const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
  const nftAddress = ethers.getAddress(MSONG_ADDRESS.trim().toLowerCase());
  const abi = [
    "function mintEnabled() view returns (bool)",
    "function setMintEnabled(bool enabled)",
    "function mintPrice() view returns (uint256)",
    "function mintOpenEdition(uint32 seed) payable returns (uint256)",
    "function totalMinted() view returns (uint256)",
  ];
  const contract = new ethers.Contract(nftAddress, abi, wallet);

  const [mintEnabled, mintPrice, totalMintedBn] = await Promise.all([
    contract.mintEnabled(),
    contract.mintPrice(),
    contract.totalMinted(),
  ]);

  console.log(
    `Current mintEnabled=${mintEnabled}, mintPrice=${mintPrice.toString()} wei, totalMinted=${totalMintedBn.toString()}`
  );

  if (!mintEnabled) {
    console.log("Enabling minting...");
    const tx = await contract.setMintEnabled(true);
    const receipt = await tx.wait();
    console.log(`  -> setMintEnabled tx ${receipt.hash}`);
  }

  const target = BigInt(TOKEN_MINT_TARGET);
  let minted = totalMintedBn;

  while (minted < target) {
    const seed = Math.floor(Math.random() * 1e9);
    console.log(`Minting token ${minted + 1n} with seed ${seed}...`);
    const tx = await contract.mintOpenEdition(seed, { value: mintPrice });
    const receipt = await tx.wait();
    console.log(`  -> minted token tx ${receipt.hash}`);
    minted = await contract.totalMinted();
  }

  console.log(`Done. totalMinted=${minted}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
