import { ethers } from "hardhat";

async function main() {
  console.log("Starting contract deployment...");
  console.log("Deploying MyERC20...");
  const MyERC20 = await ethers.getContractFactory("MyERC20");
  const myERC20 = await MyERC20.deploy();
  await myERC20.deployed();
  console.log(`MyERC20 deployed to ${myERC20.address}`);

  console.log("Deploying OrderbookLib...");
  const OrderbookLib = await ethers.getContractFactory("OrderbookLib");
  const orderbookLib = await OrderbookLib.deploy();
  await orderbookLib.deployed();
  console.log(`OrderbookLib deployed to ${orderbookLib.address}`);

  console.log("Deploying EasyBet...");
  // const EasyBet = await ethers.getContractFactory("EasyBet");
  const EasyBet = await ethers.getContractFactory("EasyBet", {
    libraries: {
      "OrderbookLib": orderbookLib.address
    }
  });
  const easyBet = await EasyBet.deploy(myERC20.address);
  await easyBet.deployed();

  console.log(`EasyBet deployed to ${easyBet.address}`);
  console.log("Deployment completed!");
  console.log("MyERC20 address:", myERC20.address);
  console.log("OrderbookLib address:", orderbookLib.address);
  console.log("EasyBet address:", easyBet.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
