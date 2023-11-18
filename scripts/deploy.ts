import { ethers } from "hardhat";

async function main() {

  const deployerAddress = (await ethers.getSigners())[0].address;

  const eas = "0xC2679fBD37d54388Ce493F1DB75320D236e1815e";
  const schemaRegistery = "0x0a7E2Ff54e76B8E6659aedc9103FB21c038050D0";
  const schema1 = "0x49e7e96fb6c07fc463c8e1720c6e2915926281cf4e0b053e6e62f210bc48f8df";
  const schema2 = "0xb43ae0f15e2b869f82e7b3703cbb2fc287d16f4c36dc941bb613a6311e92db32";

  const payingresolver = await ethers.deployContract("PayingResolver", [eas])
  await payingresolver.waitForDeployment();

  console.log(`PayingResolver deployed to: ${payingresolver.target}`);

  const easywork = await ethers.deployContract("EASYWork", [schema1, schema2, eas, schemaRegistery, payingresolver.target])

  await easywork.waitForDeployment();
  console.log(`EasyWork deployed to:, easywork.target`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
