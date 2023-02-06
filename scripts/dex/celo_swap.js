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
  console.log("get balance is", await signer.getBalance());


  let chainId = await provider.network.chainId

  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled

  await hre.run('compile');


  const proxy_addr = process.env.CELO_SWAP;

  const ETH  = "0x471EcE3750Da237f93B8E339c536989b8978a438";
  const CUSD = "0x765DE816845861e75A25fCA122bb6898B8B1282a";
  const USDT = "0xef4229c8c3250C675F21BCefa42f58EfbfF6002a";
  const USDC = "0xef4229c8c3250c675f21bcefa42f58efbff6002a";

  let swap = await hre.ethers.getContractAt("Swap", proxy_addr, signer);

  let e = ethers.utils.parseEther("0")

  let amount = ethers.utils.parseUnits("0.1", 18);

  console.log(amount.toString());


  const abi = [
    "function approve(address spender, uint256 amount) public returns (bool)",
    "function allowance(address owner, address spender) public view returns (uint256)",
    "function balanceOf(address owner) public view returns (uint256)",
    "function symbol() public view returns (string memory)",
  ];

  const erc20 = new ethers.Contract(ETH, abi, signer);
  let allowance = await erc20.allowance(myaddr, proxy_addr);

  console.log("allowance is", allowance);

  if(allowance < amount) {
      let approve_tx = await erc20.approve(proxy_addr, ethers.constants.MaxUint256);
      await approve_tx.wait();

      console.log("approve end");
  }


  let overrides = {
    value: e
  };

  // let queryParams = {
  //   destinationToken: USDC,
  //   sourceToken: ETH,
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

  let data = "0x38ed1739000000000000000000000000000000000000000000000000016345785d8a000000000000000000000000000000000000000000000000000000000000000117ee00000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000a409f6e82b250e646e1230860d266123dcd1203a0000000000000000000000000000000000000000000000000000000063dcdab80000000000000000000000000000000000000000000000000000000000000003000000000000000000000000471ece3750da237f93b8e339c536989b8978a438000000000000000000000000765de816845861e75a25fca122bb6898b8b1282a000000000000000000000000ef4229c8c3250c675f21bcefa42f58efbff6002a"

  let swapTx = await swap.swap(
      1,
      ETH,
      USDC,
      amount,
      data,
      overrides
  )
    
  await swapTx.wait()

  console.log("end", swapTx.hash);



}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
