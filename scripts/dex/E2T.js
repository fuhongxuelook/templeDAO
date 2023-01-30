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

  console.log(await signer.getBalance());


  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled

  await hre.run('compile');

  let proxy_addr = process.env.SWAP;

  const ETH = process.env.ETH;
  const USDT = process.env.USDT;

  let swap = await hre.ethers.getContractAt("Swap", proxy_addr, signer);

  let e = ethers.utils.parseEther("0.1")

  console.log(e.toString());

  let overrides = {
    value: e,
    nonce:500,
    gasLimit: 900000,
    gasPrice: 100000000000
  };

  // let queryParams = {
  //   sourceToken: ETH,
  //   destinationToken: DAI,
  //   sourceAmount: e.toString(),
  //   slippage: 1,
  //   timeout: "10000",
  //   recipientAddress: perform
  // }

  // let response = await lib.apiRequestJson(chainId, queryParams)
  // let data = lib.filterData("1inch", response);
  // console.log("data is", data);
    
  // if(data == "") {
  //   console.log("data cant fetched", data);
  // }

  data = "0x7c025200000000000000000000000000b97cd69145e5a9357b2acd6af6c5076380f17afb00000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000180000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee000000000000000000000000c2132d05d31c914a87c6611c10748aeb04b58e8f000000000000000000000000b97cd69145e5a9357b2acd6af6c5076380f17afb0000000000000000000000001a763cd36f9ebf4012b8b1507b849dab84f4f503000000000000000000000000000000000000000000000000016345785d8a0000000000000000000000000000000000000000000000000000000000000001bdef00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e70000000000000000000000000000000000000000000000000000a900001a40410d500b1d8e8ef31e21c99d1db9a6444d3adf1270d0e30db00c200d500b1d8e8ef31e21c99d1db9a6444d3adf1270604229c960e5cacf2aaeac8be68ac07ba9df81c36ae40711b8002dc6c0604229c960e5cacf2aaeac8be68ac07ba9df81c31111111254fb6c44bac0bed2854e76f90643097d000000000000000000000000000000000000000000000000000000000001bdef0d500b1d8e8ef31e21c99d1db9a6444d3adf1270000000000000000000000000000000000000000000000000016345785d8a000000000000000000000000000000000000000000000000000000cfee7c08";


  let swapTx = await swap.swap(
  	0,
  	ETH,
    USDT,
  	e,
  	data,
  	overrides
  );
  console.log(swapTx);
  await swapTx.wait()

  console.log("end", swapTx.hash);



}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
