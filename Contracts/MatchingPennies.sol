// SPDX-License-Identifier: AFL-3.0
pragma solidity >=0.8.0 <0.9.0;

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

    fallback() external {
        emit InvalidFunctionCall("An invalid function was called in this contract! Fallback triggered instead.");
    }

    function joinGame(bytes32 commitment) public payable {
        require(players.length < 2, "Game already full! Please join when this round is over!");
        require(commitments[msg.sender] == 0, "Can't play the game against yourself!");
        require(msg.value == 1 ether, "Amount sent is NOT 1 ether!");

        commitments[msg.sender] = commitment;
        players.push(msg.sender);
        emit PlayerJoined("A new player has joined the game");

        if (players.length == 2) emit CommitPhaseOver("The commit phase is now order. Registered players can begin revealing their values.");
    }

    function revealValue(bytes32 _commitment, string memory _vote) public {
        require(players.length == 2, "Can't reveal values before both players have joined!");
        require(commitments[msg.sender] != 0, "Only players who have previously joined the game can call this function!");
        require(commitments[msg.sender] == _commitment, "Invalid parameters!");
        require(commitments[msg.sender] == keccak256(abi.encodePacked(_vote)), "Invalid parameters!");
        require(votes.length < 2, "Both votes in this round already revealed!");

        if (votes.length == 1) {
            require(votes[0].player != msg.sender, "You have already revealed a value, can't do that again!");
        }
        
        votes.push(Vote(msg.sender, uint(sha256(abi.encodePacked(_vote)))));

        if (votes.length == 2) emit RevealPhaseOver("Reveal phase over. The winner can now be calculated");
    }

    function calculateWinner() public {
        require(votes.length == 2, "Not all votes have been revealed!");
        
        address winner; 

        if (votes[0].vote % 2 == votes[1].vote % 2) {
            winner = players[0];
        } else {
            winner = players[1];
        }

        //  need to reset all of my vars so that other people can join the game
        for (uint8 i = 0; i < players.length; i++) {
            commitments[players[i]] = 0;
        }
        delete players;
        delete votes;

        emit LogWinnerFound("A winner has been found!", winner);

        //  no need to use safeMaths. Solidity 0.8.0 supports checked operations by default.
        balances[winner] += 2 ether;
    }

    function withdrawBalance() public {
        uint balance = balances[msg.sender];

        balances[msg.sender] = 0;

        payable(msg.sender).transfer(balance);
    }
}