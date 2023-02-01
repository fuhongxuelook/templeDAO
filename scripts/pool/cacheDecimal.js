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
  let pool_address = process.env.G_POOL;
  let token_address = process.env.G_TOKEN;

  let pool = await hre.ethers.getContractAt("Pool", pool_address, signer);

  
  let decimals = await pool.cachedDecimals(token_address);
  console.log(decimals);

  let cacheTokenDecimal_tx = await pool.cacheTokenDecimal(token_address);
  await cacheTokenDecimal_tx.wait();

  let decimalsAfter = await pool.cachedDecimals(token_address);
  console.log(decimalsAfter);

  console.log("end");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
