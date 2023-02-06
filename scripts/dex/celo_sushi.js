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

  const proxy_addr = process.env.CELO_SWAP;

  console.log("proxy is", proxy_addr);
  let proxy = await hre.ethers.getContractAt("Swap", proxy_addr, signer);

  let _router = "0x1421bde4b10e8dd459b3bcb598810b1337d56842";
  let _name = "sushi";

  let overrides1 = {
    gasPrice: 500000000000,
  };

  let registerTx = await proxy.registerAdapter(
    _router,
    hre.ethers.utils.formatBytes32String(_name),
    overrides1
  );
  await registerTx.wait();
  console.log("sushi router is registerred");

  let index = await proxy.getAdapterByIndex(1);
  console.log(index);

  console.log(hre.ethers.utils.parseBytes32String(index._name));

  console.log("end");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
