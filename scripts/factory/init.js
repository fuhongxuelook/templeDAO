// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {

  let provider = hre.ethers.provider;
  let signer = provider.getSigner();

  const myaddr = await signer.getAddress();

  console.log(myaddr);
  console.log(await signer.getBalance());

  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled

  await hre.run('compile');


  let factory_address = process.env.G_FACTORY;
  let vault_address = process.env.G_VAULT;
  let swap_address = process.env.G_SWAP;

  let factory = await hre.ethers.getContractAt("Factory", factory_address, signer);

  let setVault_tx = await factory.setVault(vault_address);
  await setVault_tx.wait();

  let setSwap_tx = await factory.setSwap(swap_address);
  await setSwap_tx.wait();

  let setFeeto_tx = await factory.setFeeTo("0x3D2C9c796a1BFdBC803775CfffA1DeB3F78228Bb")
  await setFeeto_tx.wait();

  console.log("end");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
