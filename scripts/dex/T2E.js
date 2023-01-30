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


  const abi = [
    "function approve(address spender, uint256 amount) public returns (bool)",
    "function allowance(address owner, address spender) public view returns (uint256)",
    "function balanceOf(address owner) public view returns (uint256)",
    "function symbol() public view returns (string memory)",
  ];

  const erc20 = new ethers.Contract(USDT, abi, signer);

  let swapAmount = ethers.utils.parseUnits("0.1" , 6);
  console.log(swapAmount);
//  return;

  // check allowance
  let allowance = await erc20.allowance(myaddr, proxy_addr);
  console.log("allowance is", allowance.toString());


  let overrides = {
    nonce:504,
    gasLimit: 900000,
    gasPrice: 500000000000
  };

  if(allowance < swapAmount) {
      let approve_tx = await erc20.approve(proxy_addr, ethers.constants.MaxUint256, overrides);
      await approve_tx.wait();

      console.log("approve end");
  }

  let data = "0x7c025200000000000000000000000000b97cd69145e5a9357b2acd6af6c5076380f17afb00000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000180000000000000000000000000c2132d05d31c914a87c6611c10748aeb04b58e8f000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee00000000000000000000000055ff76bffc3cdd9d5fdbbc2ece4528ecce45047e0000000000000000000000001a763cd36f9ebf4012b8b1507b849dab84f4f50300000000000000000000000000000000000000000000000000000000000186a0000000000000000000000000000000000000000000000000012fa36e6cc130be00000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e30000000000000000000000000000000000000000000000a500008f00005300206ae4071118002dc6c055ff76bffc3cdd9d5fdbbc2ece4528ecce45047e000000000000000000000000000000000000000000000000012fa36e6cc130bec2132d05d31c914a87c6611c10748aeb04b58e8f41010d500b1d8e8ef31e21c99d1db9a6444d3adf127000042e1a7d4d0000000000000000000000000000000000000000000000000000000000000000c0611111111254fb6c44bac0bed2854e76f90643097d00000000000000000000000000000000000000000000000000000000000186a00000000000000000000000000000000000000000000000000000000000cfee7c08"

  let swapTx = await swap.swap(
  	0,
  	USDT,
    ETH,
  	swapAmount,
  	data,
    overrides
  	);
  await swapTx.wait()

  console.log("end", swapTx.hash);



}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
