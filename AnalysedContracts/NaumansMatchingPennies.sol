// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract MatchingPennies {
    enum ChoiceStatus {
        Committed,
        Revealed
    }
    struct Player {
        address pAddress;
        bytes32 pChoiceHash;
        bytes1 pChoice;
        ChoiceStatus pChoiceStatus;
    }

    Player[2] private players;
    mapping(address => uint256) playerBalances;
    address contractOwner;
    uint256 gameBalance;
    uint8 countCommitted;
    uint8 countRevealed;
    bytes1 public choiceA = "H";
    bytes1 public choiceB = "T";
    bytes1 public invalidChoice = "I";
    string[] private errors = [
        "Transaction value must be 1 ether",
        "Both players have already played their turn",
        "Please wait for all players to play their turn",
        "Both choices have already been revealed",
        "PlayerNum must be 1 or 2",
        "A player can only reveal their own choice",
        "Player choice has already been revealed",
        "Hash of provided string does not match the stored hash",
        "Add a secret password in front of your choice!",
        "Player A must reveal first"
    ];

    event ChoiceMade(uint8 playerId, bytes32 choiceHash);
    event WinnerAnnounced(uint8 winnerId, bytes1 aChoice, bytes1 bChoice);
    event Withdrawal(address playerAddress);

    constructor() {
        contractOwner = msg.sender;
        gameBalance = 0;
        countCommitted = 0;
        countRevealed = 0;
    }

    function commitChoice(bytes32 _choiceHash) public payable returns (uint8) {
        require(msg.value == 1 ether, errors[0]);
        require(countCommitted < 2, errors[1]);
        require(_choiceHash != keccak256(abi.encodePacked(choiceA)) && _choiceHash != keccak256(abi.encodePacked(choiceB)), errors[8]);

        Player memory newPlayer;
        newPlayer.pAddress = msg.sender;
        newPlayer.pChoiceHash = _choiceHash;
        newPlayer.pChoiceStatus = ChoiceStatus.Committed;
        players[countCommitted] = newPlayer;
        gameBalance += msg.value;

        countCommitted++;
        emit ChoiceMade(countCommitted, _choiceHash);
        return countCommitted;
    }

    function revealChoice(uint8 _playerNum, string memory _choiceStr) public {
        require(countCommitted == 2, errors[2]);
        require(countRevealed < 2, errors[3]);
        require(_playerNum > 0 && _playerNum < 3, errors[4]);
        require(countRevealed == _playerNum - 1, errors[9]);

        Player storage player = players[_playerNum - 1];
        require(player.pAddress == msg.sender, errors[5]);
        require(player.pChoiceStatus != ChoiceStatus.Revealed, errors[6]);
        require(player.pChoiceHash == keccak256(abi.encodePacked(_choiceStr)), errors[7]);

        bytes1 choice = bytes(_choiceStr)[0];
        if (choice != choiceA && choice != choiceB) {
            player.pChoice = invalidChoice;
        } else {
            player.pChoice = choice;
        }
        player.pChoiceStatus = ChoiceStatus.Revealed;
        countRevealed++;

        if (countRevealed == 2) {
            announceWinner();
        }
    }

    function announceWinner() private {
        assert(countRevealed == 2);

        Player memory playerA = players[0];
        Player memory playerB = players[1];
        assert(playerA.pChoiceStatus == ChoiceStatus.Revealed && playerB.pChoiceStatus == ChoiceStatus.Revealed);

        uint8 winnerId;
        uint256 b = gameBalance;
        gameBalance = 0;
        if (playerA.pChoice != invalidChoice && playerB.pChoice != invalidChoice) {
            if (playerA.pChoice == playerB.pChoice) {
                winnerId = 1;
                playerBalances[playerA.pAddress] += b;
            } else {
                winnerId = 2;
                playerBalances[playerB.pAddress] += b;
            }
        } else if (playerB.pChoice != invalidChoice && playerA.pChoice == invalidChoice) {
            winnerId = 2;
            playerBalances[playerB.pAddress] += b;
        } else if (playerA.pChoice != invalidChoice && playerB.pChoice == invalidChoice) {
            winnerId = 1;
            playerBalances[playerA.pAddress] += b;
        }

        countCommitted = 0;
        countRevealed = 0;
        emit WinnerAnnounced(winnerId, playerA.pChoice, playerB.pChoice);
    }

    function withdraw() public {
        uint256 b = playerBalances[msg.sender];
        playerBalances[msg.sender] = 0;
        payable(msg.sender).transfer(b);
        emit Withdrawal(msg.sender);
    }

    function getBalance() public view returns (uint256) {
        return playerBalances[msg.sender];
    }

    function getContractBalance() public view returns (uint256) {
        require(msg.sender == contractOwner);
        return address(this).balance;
    }
}
