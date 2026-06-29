// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract BombGrid {
    using ECDSA for bytes32;

    uint8 public constant GRID_SIZE = 9;
    uint8 public constant BOMB_COUNT = 3;

    enum Phase {
        WaitingForPlayers,
        Commit,
        Play,
        Reveal,
        Done
    }

    Phase public phase;

    address public deployer;

    address public player1;
    address public player2;
    address public currentTurn;
    address public loser;

    mapping(address => bytes32) public commitment;
    mapping(address => bool) public hasCommitted;
    mapping(address => uint8) public bombsFound;
    mapping(address => bool) public hasRevealed;

    mapping(address => mapping(uint8 => bool)) public cellGuessed;

    struct Response {
        address responder;
        uint8 cell;
        bool isBomb;
        uint256 round;
    }
    Response[] public responses;

    uint256 public roundNumber;

    uint8 public pendingCell;
    bool public guessPending;
    address public cheater;

    event PlayerJoined(address player);
    event BoardCommitted(address player);
    event GameStarted(address firstToGuess);
    event GuessMade(address guesser, uint8 cell, uint256 round);
    event ResponseGiven(address responder, uint8 cell, bool isBomb);
    event BombFound(address victim, uint8 bombsFoundSoFar);
    event GameOver(address loser);
    event BoardVerified(address player, bool honest);
    event CheaterDetected(address cheater);
    event Payout(address winner, uint256 amount);

    constructor(address deployerAddress) {
        deployer = deployerAddress;
        phase = Phase.WaitingForPlayers;
    }

    modifier onlyPlayer() {
        require(msg.sender == player1 || msg.sender == player2, "Not a player");
        _;
    }

    function getAuthHash(address player) public view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked("Authorized player:", player, address(this))
            );
    }

    function joinGame(bytes memory signature) external payable {
        require(msg.value == 1 ether, "Must deposit EXACTLY 1 ETH");
        require(phase == Phase.WaitingForPlayers, "Game already started");
        require(player1 == address(0) || player2 == address(0), "Game full");
        require(msg.sender != player1, "Already joined");

        // Verify deployer signed this player's address
        bytes32 rawHash = getAuthHash(msg.sender);
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(rawHash);
        address signer = ECDSA.recover(ethHash, signature);
        require(signer == deployer, "Deployer did not authorize this player");

        if (player1 == address(0)) {
            player1 = msg.sender;
        } else {
            player2 = msg.sender;
            phase = Phase.Commit;
        }

        emit PlayerJoined(msg.sender);
    }

    function commitBoard(bytes32 _commitment) external onlyPlayer {
        require(phase == Phase.Commit, "Not the commit phase");
        require(!hasCommitted[msg.sender], "Already committed");

        // Store the commitment hash under the player's address
        commitment[msg.sender] = _commitment;
        hasCommitted[msg.sender] = true;

        emit BoardCommitted(msg.sender);

        // If BOTH players have committed -> start the game
        if (hasCommitted[player1] && hasCommitted[player2]) {
            phase = Phase.Play;
            currentTurn = player1;
            emit GameStarted(player1);
        }
    }

    function buildCommitment(
        uint8 bomb0,
        uint8 bomb1,
        uint8 bomb2,
        bytes32 salt
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(bomb0, bomb1, bomb2, salt));
    }

    function guess(uint8 cell) external onlyPlayer {
        require(phase == Phase.Play, "Not the play phase");
        require(msg.sender == currentTurn, "Not your turn");
        require(cell < GRID_SIZE, "Cell must be 0 to 8");
        require(!guessPending, "Waiting for opponent to respond");
        require(!cellGuessed[msg.sender][cell], "Cell already guessed");

        pendingCell = cell;
        guessPending = true;
        cellGuessed[msg.sender][cell] = true;
        roundNumber++;

        emit GuessMade(msg.sender, cell, roundNumber);
    }

    function respond(uint8 cell, bool isBomb) external onlyPlayer {
        require(phase == Phase.Play, "Not the play phase");
        require(msg.sender != currentTurn, "Cannot respond to your own guess");
        require(guessPending, "No pending guess to respond to");
        require(cell == pendingCell, "Respond to the correct cell");

        responses.push(
            Response({
                responder: msg.sender,
                cell: cell,
                isBomb: isBomb,
                round: roundNumber
            })
        );

        emit ResponseGiven(msg.sender, cell, isBomb);

        if (isBomb) {
            bombsFound[msg.sender]++;
            emit BombFound(msg.sender, bombsFound[msg.sender]);

            // All 3 bombs found -> responder loses
            if (bombsFound[msg.sender] == BOMB_COUNT) {
                loser = msg.sender;
                phase = Phase.Reveal;
                guessPending = false;
                emit GameOver(loser);
                return;
            }
        }

        guessPending = false;
        currentTurn = msg.sender;
    }

    function revealBoard(
        uint8 bomb0,
        uint8 bomb1,
        uint8 bomb2,
        bytes32 salt
    ) external onlyPlayer {
        require(
            phase == Phase.Reveal || phase == Phase.Done,
            "Not reveal phase"
        );
        require(!hasRevealed[msg.sender], "You already revealed your board");

        bytes32 recomputed = keccak256(
            abi.encodePacked(bomb0, bomb1, bomb2, salt)
        );
        require(
            recomputed == commitment[msg.sender],
            "Commitment mismatch - cheater!"
        );

        uint8[9] memory grid;
        grid[bomb0] = 1;
        grid[bomb1] = 1;
        grid[bomb2] = 1;

        // Checking honesty from Response[]
        bool honest = true;
        for (uint256 i = 0; i < responses.length; i++) {
            Response memory r = responses[i];
            if (r.responder == msg.sender) {
                bool actualIsBomb = (grid[r.cell] == 1);
                if (r.isBomb != actualIsBomb) {
                    honest = false;
                    cheater = msg.sender;
                    emit CheaterDetected(msg.sender);
                    break;
                }
            }
        }

        hasRevealed[msg.sender] = true;
        emit BoardVerified(msg.sender, honest);

        // Go to Phase Done
        if (hasRevealed[player1] && hasRevealed[player2]) {
            phase = Phase.Done;
            _settlePayout();
        }
    }

    function _settlePayout() internal {
        uint256 prize = address(this).balance;

        // Case 1: someone cheated -> honest player gets everything
        if (cheater != address(0)) {
            address honest = getOpponent(cheater);
            (bool ok, ) = payable(honest).call{value: address(this).balance}(
                ""
            );
            require(ok, "Transfer failed");
            emit Payout(honest, address(this).balance);
            return;
        } else {
            // both honest → game winner gets everything
            address winner = getOpponent(loser);
            (bool ok, ) = payable(winner).call{value: prize}("");
            require(ok, "Transfer failed");
            emit Payout(winner, prize);
        }
    }

    function getOpponent(address player) public view returns (address) {
        if (player == player1) return player2;
        if (player == player2) return player1;
        revert("Not a player");
    }

    function getPhase() public view returns (uint8) {
        return uint8(phase);
    }

    // Returns how many bombs player 1 and 2 has found
    function getScore()
        public
        view
        returns (uint8 p1BombsFound, uint8 p2BombsFound)
    {
        return (bombsFound[player1], bombsFound[player2]);
    }
}
