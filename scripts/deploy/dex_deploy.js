// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled

  await hre.run('compile');

  let provider = ethers.provider;
  let signer = provider.getSigner();

  let my_address = await signer.getAddress();

  console.log("my address ", my_address);

  const Swap = await hre.ethers.getContractFactory("Swap");
  const swap = await Swap.deploy()

  console.log("swap address is:", swap.address)

  let implement = swap.address;

  const abi = [
    "function initialize() external"
  ];
  const initialize = new ethers.Contract(implement, abi, signer);

  let tx = await initialize.populateTransaction.initialize();
  let data = tx.data

  console.log("data is", tx.data);

  const SaviProxy = await hre.ethers.getContractFactory("SaviProxy");
  const proxy = await SaviProxy.deploy(implement, data)

  console.log("proxy address is:", proxy.address)


}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
