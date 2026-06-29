const { ethers } = require("ethers");

const args = process.argv.slice(2);

const BOMBS = JSON.parse(args[0]);
const SALT = args[1];

async function generateCommitment(bombs, salt) {
  const [bomb0, bomb1, bomb2] = bombs;

  const packed = ethers.solidityPacked(
    ["uint8", "uint8", "uint8", "bytes32"],
    [bomb0, bomb1, bomb2, salt],
  );
  const commitment = ethers.keccak256(packed);

  console.log("Salt: ", salt);
  console.log("Commitment: ", commitment);
}

async function main() {
  try {
    if (args.length != 2)
      throw Error("needs EXACTLY 2 arguments - [BOMBS], [SALT]");
    if (!Array.isArray(BOMBS))
      throw Error(`The bomb should be in Array format, e.g. "[0,1,2]" `);
    if (!/^0x[0-9a-fA-F]{64}$/.test(SALT)) {
      throw Error("Invalid salt - Salt must be a bytes32 hex value.");
    }
    await generateCommitment(BOMBS, SALT);
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
