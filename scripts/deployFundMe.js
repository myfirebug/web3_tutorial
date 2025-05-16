// import ethers.js
const { ethers } = require("hardhat");
// create main function
async function main() {
  // create factory
  const fundMeFactory = await ethers.getContractFactory("FundMe");
  console.log("constract deploying");
  // deploy contract from factory
  const fundMe = await fundMeFactory.deploy(10);

  console.log(
    `contract has been deployed successfully, contract address is ${fundMe.target}`
  );
  if (hre.network.config.chainId == 11155111 && process.env.ETHERSCAN_API_KEY) {
    console.log("waiting for 5 confirmations");
    await fundMe.deploymentTransaction().wait(5);
    await verifyFundMe(fundMe.target, [10]);
  } else {
    console.log("verification skipped..");
  }
}

async function verifyFundMe(fundMeAddr, args) {
  await hre.run("verify:verify", {
    address: fundMeAddr,
    constructorArguments: args,
  });
}
// execute main function
main()
  .then()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
