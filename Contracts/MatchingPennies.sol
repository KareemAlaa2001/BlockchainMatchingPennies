// SPDX-License-Identifier: AFL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract MatchingPennies {

    event LogWinnerFound(string, address);
    event PlayerJoined(string);
    event CommitPhaseOver(string);
    event RevealPhaseOver(string);
    event InvalidFunctionCall(string);

    struct Vote {
        address player;
        uint vote;
    }

    mapping(address => uint) balances;

    mapping(address => bytes32) commitments;
    address[] private players;
    Vote[] votes;
    uint private revealPhaseEndTime;

    fallback() external {
        emit InvalidFunctionCall("An invalid function was called in this contract! Fallback triggered instead.");
    }

    function joinGame(bytes32 commitment) public payable {
        //  either we are in a clean slate new game or we are resetting a previously full game only AFTER the game time ran out.
        require(players.length < 2 || (revealPhaseEndTime != 0 && revealPhaseEndTime < block.timestamp), "Game already full! Please join when this round is over!");
        require(commitments[msg.sender] == 0, "Can't play the game against yourself!");
        require(msg.value == 1 ether, "Amount sent is NOT 1 ether!");

        //  this means that joinGame was called to reset the game state after the previous game ended with both players griefing
        if (revealPhaseEndTime != 0) {
            //  need to reset the state. 
            assert(players.length == 2);
            resetState();
        }

        commitments[msg.sender] = commitment;
        players.push(msg.sender);
        emit PlayerJoined("A new player has joined the game");

        if (players.length == 2) {
            revealPhaseEndTime = add(block.timestamp, 1 hours);
            emit CommitPhaseOver("The commit phase is now order. Registered players can begin revealing their values. The reveal phase will end in 1 hour.");
        }
    }

    function revealValue(bytes32 _commitment, string memory _vote) public {
        require(players.length == 2, "Can't reveal values before both players have joined!");
        require(commitments[msg.sender] != 0, "Only players who have previously joined the game can call this function!");
        require(commitments[msg.sender] == _commitment, "Invalid parameters!");
        require(commitments[msg.sender] == keccak256(abi.encodePacked(_vote)), "Invalid parameters!");
        require(votes.length < 2, "Both votes in this round already revealed!");
        require(block.timestamp < revealPhaseEndTime, "Can't reveal a value after the reveal phase has ended!");

        if (votes.length == 1) {
            require(votes[0].player != msg.sender, "You have already revealed a value, can't do that again!");
        }
        
        votes.push(Vote(msg.sender, uint(sha256(abi.encodePacked(_vote)))));

        if (votes.length == 2) emit RevealPhaseOver("Reveal phase over. The winner can now be calculated");
    }

    function calculateWinner() public {
        require(revealPhaseEndTime != 0, "Can't call calculateWinner() unless both players have joined the game!");
        require(votes.length == 2 || block.timestamp > revealPhaseEndTime, "Not all votes have been revealed!");

        address winner; 
        bool winnerFound = true;

        //  if nobody griefed and the game ended as expected.
        if (votes.length == 2) {
            if (votes[0].vote % 2 == votes[1].vote % 2) {
                winner = players[0];
            } else {
                winner = players[1];
            }
        //  if one player griefed, reward the other player with an auto win
        } else if (votes.length == 1) {
            winner = votes[0].player;
        //  if both players griefed, both get punished. Nobody gets their ether back.
        //  need to keep this condition in case a different person calls this function
        } else {
            winnerFound = false;
        }

        resetState();

        if (winnerFound) {
            emit LogWinnerFound("A winner has been found!", winner);

            //  using safemaths-esque add to support solidity version 0.7 overlflow safety
            balances[winner] = add(balances[winner],2 ether);
        }
        
    }

    function withdrawBalance() public {
        uint balance = balances[msg.sender];

        balances[msg.sender] = 0;

        payable(msg.sender).transfer(balance);
    }

    function resetState() private {
        commitments[players[0]] = 0;
        commitments[players[1]] = 0;

        delete players;
        delete votes;
        delete revealPhaseEndTime;
    }

    function add(uint a, uint b) private pure returns (uint) {
        uint c = a + b;
        require(c >= a);
        return c;
    }
}