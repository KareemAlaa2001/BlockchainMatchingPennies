// SPDX-License-Identifier: AFL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract MatchingPennies {

    event LogWinnerFound(string);
    event PlayerJoined(string);
    event CommitPhaseOver(string);
    event RevealPhaseOver(string);

    struct Vote {
        address player;
        bool vote;
    }

    mapping(address => bytes32) commitments;
    address[] private players;
    Vote[] votes;

    constructor() {
        

    }

    function joinGame(bytes32 commitment) public payable {
        require(msg.value == 1 ether, "Amount sent is NOT 1 ether!");
        require(players.length < 2, "Game already full! Please join when this round is over!");
        require(commitments[msg.sender] == 0, "Can't play the game against yourself!");

        commitments[msg.sender] = commitment;
        players.push(msg.sender);
        emit PlayerJoined("A new player has joined the game");

        if (players.length == 2) emit CommitPhaseOver("The commit phase is now order. Registered players can begin revealing their values.");
    }

    function revealValue(bytes32 _commitment, bool _vote) public {
        require(players.length == 2, "Can't reveal values before both players have joined!");
        require(commitments[msg.sender] == _commitment, "Only players who have previously joined the game can call this function!");
        require(commitments[msg.sender] == keccak256(abi.encode(_vote)), "Invalid parameters!");
        require(votes.length < 2, "Both votes in this round already revealed!");

        votes.push(Vote(msg.sender, _vote));

        if (votes.length == 2) emit RevealPhaseOver("Reveal phase over. The winner can now be calculated");
    }

    function calculateWinner() public {
        require(votes.length == 2, "Votes have not yet been revealed!");
        
        address payable winner; 

        if (votes[0].vote == votes[1].vote) {
            winner = payable(votes[0].player);
        } else {
            winner = payable(votes[1].player);
        }

        emit LogWinnerFound("A winner has been found!");

        //  need to reset all of my vars so that other people can join the game
        for (uint8 i = 0; i < players.length; i++) {
            commitments[players[i]] = 0;
        }
        delete players;
        delete votes;

        //  then pay the winner
        winner.transfer(2 ether);
    }
}