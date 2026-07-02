# BombGrid - Smart Contract Game

A 2-player bomb guessing game on Ethereum using cryptographic
commitments and ECDSA signatures.

Each player hides 3 bombs on a 3x3 grid and takes turns guessing
the opponent's coordinates. The first player to find 
their opponent's 3 bombs **loses**. Each player stakes 1 ETH - the winner takes both.

> Note: Inspiration from https://youtube.com/shorts/ldN-5lwHDi4?is=670kv4KRJcD7449r

---

## Files

| File | Purpose |
|---|---|
| `BombGrid.sol` | Solidity smart contract - deploy this in Remix |
| `helper.js` | Off-chain JS - generates deployer signatures for player authorization |

---

## Cryptographic Primitives

### 1. Commitment
Used in `commitBoard()` and verified in `revealBoard()`.

Each player computes a commitment before the game starts:
```
commitment = keccak256(bomb0, bomb1, bomb2, salt)
```

The contract stores only the hash - it cannot see actual bomb
positions. The salt prevents brute-force guessing (only 84 possible
combinations exist in a 3x3 grid without salt).

In the Reveal phase, the contract recomputes the hash with the
revealed values and checks it matches the original commitment.
If it does not match, or if any response during play contradicts
the actual bombs, the player is marked as a cheater and loses
their staked ETH.

### 2. ECDSA Signature
Used in `joinGame()`.

The deployer signs each player's address off-chain to authorize
them to join. The message signed is:
```
keccak256("Authorized player:" + playerAddress + contractAddress)
```

The contract uses `ECDSA.recover()` to verify the signature came
from the deployer. This prevents unauthorized players from joining.
Including the contract address in the message prevents the signature
from being reused on a different deployed contract.

---

## Cell Encoding

```
       Col1  Col2  Col3
  RowA [ 0 ][ 1 ][ 2 ]
  RowB [ 3 ][ 4 ][ 5 ]
  RowC [ 6 ][ 7 ][ 8 ]

  A1=0  A2=1  A3=2
  B1=3  B2=4  B3=5
  C1=6  C2=7  C3=8
```

---

## Phases

The Game has 5 Phases

| Phase | Description |
|---|---|
| WaitingForPlayers | Waiting for players to join the game |
| Commit | Deciding their bombs in their grids |
| Play | Guessing opponent's guess and responding to their answer |
| Reveal | Revealing each player's bomb placement and finding cheater |
| Done | End of the game |

---

## Scripts

### GenerateCommitment.js

An off-chain helper script to generate `bytes32` Commitment.
This script is taking 2 arguments: `BOMBS` and `SALT`

Run:

```bash
node GenerateCommitment.js '[bomb0,bomb1,bomb2]' 'salt'
```

Example:

```bash
node GenerateCommitment.js '[0,4,8]' '0x8f3a6d9c41e7b2f05c8d13a964be27f1d5c7048a9e6b32f0c147da85b39e62ac'
```

### GenerateSignature.js

An off-chain helper script to authorize the players by
giving back a signature for the player during the game.
This script is taking 3 arguments: `CONTRACT_ADDRESS`, 
`PLAYER_ADDRESS` and `DEPLOYER_PRIVATE_KEY`.

Run:

```bash
node GenerateSignature.js 'contract_address' 'player_address' 'private_key'
```

Example:

```bash
node GenerateSignature.js '0x...' '0x...' '0x...'
```
---

## Requirements

- Remix IDE: https://remix.ethereum.org
- Node.js >= 16
- ethers v6: `npm install ethers@latest`

---

## Step by Step - How to Run

---

### STEP 1 - Deploy the Contract

1. Open Remix IDE
2. Create new file -> paste contents of `BombGrid.sol`
3. Go to **Solidity Compiler** tab
4. Select compiler version `0.8.20`
5. Click **Compile BombGrid.sol**
6. Go to **Deploy & Run Transactions** tab
7. Environment -> **Remix VM (Cancun)**
8. Click **Deploy**
9. Copy the contract address from **Deployed Contracts** section

```
Save:
CONTRACT_ADDRESS = 0x...
```

In this game, **deployer** is needed as someone that will deploy the game and authorize the player.
Generate its private key: **3 dots -> Generate new key** and save it.

> Note: Remix has limitation that an account with a private key is unable to be created.
> Therefore, a deployer is needed to authorize each players and give back signature of each of them.

```
Save:
DEPLOYER_ADDRESS     = 0x...  (account selected when you deployed)
DEPLOYER_PRIVATE_KEY = 0x...  (from Generate new key)
```

### STEP 2 - Authorize Player 1 (Deployer runs this)

Run:
```bash
node GenerateSignature.js [CONTRACT_ADDRESS] [PLAYER_ADDRESS] [DEPLOYER_PRIVATE_KEY]
```
> Note: The variables inside the **[]** needs to be edited.

Output:
```
signature : 0xabc123...
```

Save this signature - give it to Player 1.

---

### STEP 3 - Player 1 Joins

In Remix:
- Account dropdown -> select **Player 1's address**
- Set **VALUE = 1 ETH**
- Find `joinGame()` function
- Paste Player 1's signature into the field
- Click **transact**

---

### STEP 4 - Authorize Player 2 (Deployer runs this)

Run:
```bash
node GenerateSignature.js [CONTRACT_ADDRESS] [PLAYER_ADDRESS] [DEPLOYER_PRIVATE_KEY]
```

Save the new signature - give it to Player 2.

---

### STEP 5 - Player 2 Joins

In Remix:
- Account dropdown -> select **Player 2's address**
- Set **VALUE = 1 ETH**
- Find `joinGame()` function
- Paste Player 2's signature
- Click **transact**
- Phase is now **Commit (1)**
- Contract now holds **2 ETH**

---

### STEP 6 - Player 1 Commits Their Board

Player 1 picks 3 bomb positions and computes their commitment.

In Remix, call `buildCommitment` (blue button):
```
bomb0 : 0      (your chosen cells)
bomb1 : 4
bomb2 : 8
salt  : 0x8f3a6d9c41e7b2f05c8d13a964be27f1d5c7048a9e6b32f0c147da85b39e62ac
```

Copy the output hash.

```
Save (Player 1 keeps secret):
P1_BOMBS      = [0, 4, 8]
P1_SALT       = 0x8f3a6d9c41e7b2f05c8d13a964be27f1d5c7048a9e6b32f0c147da85b39e62ac
P1_COMMITMENT = 0x...  (output from buildCommitment)
```

In Remix:
- Account -> **Player 1**
- Find `commitBoard()` function
- Paste `P1_COMMITMENT` into `_commitment` field
- Click **transact**

---

### STEP 7 - Player 2 Commits Their Board

Player 2 uses different bombs and a different salt.

In Remix, call `buildCommitment`:
```
bomb0 : 2
bomb1 : 3
bomb2 : 7
salt  : 0x1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b
```

```
Save (Player 2 keeps secret):
P2_BOMBS      = [2, 3, 7]
P2_SALT       = 0x1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b
P2_COMMITMENT = 0x...
```

In Remix:
- Account -> **Player 2**
- Find `commitBoard()`
- Paste `P2_COMMITMENT`
- Click **transact**
- Phase is now **Play (2)** 

---

### STEP 8 - Gameplay (repeat until someone loses)

Player 1 guesses first. Players alternate after each response.

**Guesser's turn:**
- Account -> switch to the **current player**
- Find `guess()` function
- Type a cell number (0-8)
- Click **transact**

**Responder's turn:**
- Account -> switch to the **other player**
- Find `respond()` function:
```
cell   : (the cell that was just guessed)
isBomb : true if it is one of your bombs, false if not
```
- Click **transact**
- If bomb found -> `BombFound` event shows count

Repeat - switching turns each round - until one player has
`bombsFound == 3`.

Console -> `GameOver` event 
Phase is now **Reveal (3)** 

---

### STEP 9 - Reveal Phase (both players)

Both players must reveal their actual bomb positions and salt.
The contract verifies honesty and pays out the winner.

**Player 1 reveals:**
- Account -> **Player 1**
- Find `revealBoard()` function:
```
bomb0 : 0 
bomb1 : 4
bomb2 : 8
salt  : 0x8f3a...  
```
- Click **transact**
- Console -> `BoardVerified (player1, true)` 

**Player 2 reveals:**
- Account -> **Player 2**
- Find `revealBoard()`:
```
bomb0 : 2          (your actual bombs from Step 8)
bomb1 : 3
bomb2 : 7
salt  : 0x1a2b...  (your salt from Step 8)
```
- Click **transact**
- Console -> `BoardVerified (player2, true)` 
- Console -> `Payout (winner, 2000000000000000000)` 
- Phase is now **Done (4)** 
- Winner receives **2 ETH**

---

## Payout Logic

| Scenario | Result |
|---|---|
| Both honest, game played fairly | Winner gets 2 ETH |
| Player lied during respond() | Cheater detected in reveal, honest player gets 2 ETH |
| Commitment does not match revealed bombs | Caught as cheater, repeat the process with the honest answer |

---

## Quick Reference - All Functions

| Function | Who calls it | Phase |
|---|---|---|
| `joinGame(signature)` | Each player with 1 ETH | WaitingForPlayers |
| `commitBoard(_commitment)` | Each player | Commit |
| `buildCommitment(b0,b1,b2,salt)` | Anyone (verification helper) | Any |
| `guess(cell)` | Current player | Play |
| `respond(cell, isBomb)` | Other player | Play |
| `revealBoard(b0,b1,b2,salt)` | Each player | Reveal |
| `getPhase()` | Anyone | Any |
| `getScore()` | Anyone | Any |
| `getBalance()` | Anyone | Any |

---

## Compiler and Library Versions

| Tool | Version |
|---|---|
| Solidity | ^0.8.20 |
| OpenZeppelin | 5.x |
| Node.js | >= 16 |
| ethers.js | 6.x |

---
