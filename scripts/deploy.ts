import { ethers, network } from "hardhat";

async function main() {

  const deployerAddress = (await ethers.getSigners())[0].address;
  let eas, schemaRegistery, schema1, schema2;
  if (network.name === "sepolia") {
    eas = "0xC2679fBD37d54388Ce493F1DB75320D236e1815e";
    schemaRegistery = "0x0a7E2Ff54e76B8E6659aedc9103FB21c038050D0";
    schema1 = "0x72cd0bda6e54d642f92422c48a5efce01650ceecc3cc0514e60eb8908bb5ffb6";
    schema2 = "0x5da724592c0045590d640e5862e1bda78d58d9242caaf6f03036706f2f8dbbee";
  }
  else if (network.name === "arbitrumGoerli") {
    eas = "0xaEF4103A04090071165F78D45D83A0C0782c2B2a";
    schemaRegistery = "0x55D26f9ae0203EF95494AE4C170eD35f4Cf77797";
    schema1 = "0x72cd0bda6e54d642f92422c48a5efce01650ceecc3cc0514e60eb8908bb5ffb6"; // change this
    schema2 = "0x5da724592c0045590d640e5862e1bda78d58d9242caaf6f03036706f2f8dbbee"; // change this
  }
  else if (network.name == "lineaGoerli") {
    eas = "0xaEF4103A04090071165F78D45D83A0C0782c2B2a";
    schemaRegistery = "0x55D26f9ae0203EF95494AE4C170eD35f4Cf77797";
    schema1 = "0x72cd0bda6e54d642f92422c48a5efce01650ceecc3cc0514e60eb8908bb5ffb6"; // change this
    schema2 = "0x5da724592c0045590d640e5862e1bda78d58d9242caaf6f03036706f2f8dbbee"; // change this
  }
  else {
    console.log("Unsupported network")
  }

  const payingresolver = await ethers.deployContract("PayingResolver", [eas])
  await payingresolver.waitForDeployment();

  console.log(`PayingResolver deployed to: ${payingresolver.target}`);

  const easywork = await ethers.deployContract("EASYWork", [schema1, schema2, eas, schemaRegistery, payingresolver.target])
  await easywork.waitForDeployment();

  console.log(`EasyWork deployed to:, ${easywork.target}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
