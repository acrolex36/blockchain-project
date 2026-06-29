const { ethers } = require("ethers");

const args = process.argv.slice(2);

const CONTRACT_ADDRESS = args[0];

const PLAYER_ADDRESS = args[1];

const DEPLOYER_PRIVATE_KEY = args[2];

async function authorizePlayer(playerAddress, contractAddress, deployerKey) {
  const wallet = new ethers.Wallet(deployerKey);

  const rawHash = ethers.solidityPackedKeccak256(
    ["string", "address", "address"],
    ["Authorized player:", playerAddress, contractAddress],
  );

  const signature = await wallet.signMessage(ethers.getBytes(rawHash));

  console.log("Deployer address: ", wallet.address);
  console.log("Player: ", playerAddress);
  console.log("Signature: ", signature);
}

async function main() {
  try {
    if (args.length !== 3) {
      throw Error(
        "needs EXACTLY 3 arguments - [CONTRACT_ADDRESS], [PLAYER_ADDRESS], [DEPLOYER_PRIVATE_KEY]",
      );
    }

    if (!ethers.isAddress(PLAYER_ADDRESS)) {
      throw Error("Invalid player address.");
      process.exit(1);
    }

    if (!ethers.isAddress(CONTRACT_ADDRESS)) {
      throw Error("Invalid game contract address.");
      process.exit(1);
    }

    await authorizePlayer(
      PLAYER_ADDRESS,
      CONTRACT_ADDRESS,
      DEPLOYER_PRIVATE_KEY,
    );
  } catch (err) {
    console.error("\n Error:", err.message || err);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
