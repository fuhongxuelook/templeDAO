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
  let pool_address = process.env.G_POOL;

  let vault = await hre.ethers.getContractAt("Vault", vault_address, signer);

  // let addPoolAllowedToken_tx = await vault.addPoolAllowedToken(token_address, 1);
  // await addPoolAllowedToken_tx.wait();
  // return;

  // let addTokenAllowed_tx = await vault.addTokenAllowed(token_address);
  // await addTokenAllowed_tx.wait();
  // return;
  
  const abi = [
    "function approve(address spender, uint256 amount) public returns (bool)",
    "function allowance(address owner, address spender) public view returns (uint256)",
    "function balanceOf(address owner) public view returns (uint256)",
    "function symbol() public view returns (string memory)",
  ];

  const erc20 = new ethers.Contract(token_address, abi, signer);

  let amount = ethers.utils.parseEther("1");

  // check allowance
  let allowance = await erc20.allowance(myaddr, vault_address);
  console.log("allowance is", allowance.toString());

  let balance = await erc20.balanceOf(myaddr);
  console.log("balance is ", ethers.utils.formatEther(balance));

  if(allowance < amount) {
      let approve_tx = await erc20.approve(vault_address, ethers.constants.MaxUint256);
      await approve_tx.wait();

      console.log("approve end");
  }


  let allowance_pool = await erc20.allowance(vault_address, pool_address);
  console.log("allowance_pool is", allowance_pool.toString());
  if(allowance_pool < amount) {
      let approvepool_tx = await vault.approveToPool(1);
      await approvepool_tx.wait();

      console.log("approve end");
  }

  let deposit_tx = await vault.deposit(token_address, amount, 1);
  await deposit_tx.wait();

  console.log(deposit_tx.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
