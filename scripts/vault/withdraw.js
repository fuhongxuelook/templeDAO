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
  let token_address = process.env.G_TOKEN;

  let vault = await hre.ethers.getContractAt("Vault", vault_address, signer);


  let amount = ethers.utils.parseEther("0.001");

  let withdraw_tx = await vault.withdraw(token_address, amount, 0);
  await withdraw_tx.wait();

  console.log(withdraw_tx.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
