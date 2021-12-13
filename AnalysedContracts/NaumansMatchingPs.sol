// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract MatchingPennies {
    enum GameStatus {
        Initiated,
        CommitPhase,
        RevealPhase,
        AwaitingWinner,
        Completed,
        Cancelled
    }
    struct Game {
        bool isGame;
        GameStatus status;
        address player1;
        address player2;
        bytes32[2] choiceCommits;
        bool[2] choices;
        bool[2] committed;
        bool[2] revealed;
        uint256 gameBalance;
    }

    address private contractOwner;
    mapping(uint256 => Game) games;
    mapping(address => uint256) playerBalances;
    uint256 public numGames;
    bool maxGamesReached;
    string[13] errors = [
        "No more games can be created",
        "Transaction value must be 1 ether",
        "GameId does not exist",
        "The game is not in the commit phase",
        "The game is not in the reveal phase",
        "You are not a player in this game",
        "Player choice has already been committed",
        "Player choice has already been revealed",
        "Hash of provided string does not match the stored hash",
        "The game winner cannot be announced yet",
        "Cannot add to the player's balance, integer overflow",
        "The game cannot be cancelled by you",
        "You are not allowed to play with yourself"
    ];

    modifier msgValue() {
        require(msg.value == 1 ether, errors[1]);
        _;
    }
    modifier isGame(uint256 _gameId) {
        require(games[_gameId].isGame, errors[2]);
        _;
    }
    modifier isPlayer(uint256 _gameId) {
        require(msg.sender == games[_gameId].player1 || msg.sender == games[_gameId].player2, errors[5]);
        _;
    }
    modifier gStatus(uint256 _gameId, GameStatus _status, string memory _err) {
        require(games[_gameId].status == _status, _err);
        _;
    }

    event ChoiceCommited(uint256 gameId, uint8 playerNum, bytes32 choiceHash);
    event ChoiceRevealed(uint256 gameId, uint8 playerNum, bool pChoice);
    event Winner(uint256 gameId, address winner, bool choiceP1, bool choiceP2);
    event Withdrawal(address playerAddress);
    event StatusUpdate(uint256 gameId, GameStatus gameStatus);

    constructor() {
        contractOwner = msg.sender;
        numGames = 0;
        maxGamesReached = false;
    }

    function startNewGame() public payable msgValue() returns (uint256 gameId) {
        require(!maxGamesReached, errors[0]);
        uint256 id = numGames;
        if (numGames + 1 < numGames) {
            maxGamesReached = true;
        } else {
            numGames++;
        }

        Game memory newGame;
        newGame.isGame = true;
        newGame.status = GameStatus.Initiated;
        newGame.player1 = msg.sender;
        newGame.gameBalance += msg.value;
        games[id] = newGame;
        emit StatusUpdate(id, newGame.status);
        return id;
    }

    function acceptGame(uint256 _gameId) public payable msgValue() isGame(_gameId) gStatus(_gameId, GameStatus.Initiated, errors[5]) {
        Game storage game = games[_gameId];
        assert(game.gameBalance + msg.value > game.gameBalance);
        require(msg.sender != game.player1, errors[12]);

        game.player2 = msg.sender;
        game.gameBalance += msg.value;
        game.status = GameStatus.CommitPhase;
        emit StatusUpdate(_gameId, game.status);
    }

    function commitChoice(uint256 _gameId, bytes32 _hash) public isGame(_gameId) isPlayer(_gameId) gStatus(_gameId, GameStatus.CommitPhase, errors[3]) {
        Game storage game = games[_gameId];
        uint8 playerId = msg.sender == game.player1 ? 0 : 1;
        require(!game.committed[playerId], errors[6]);

        game.choiceCommits[playerId] = _hash;
        game.committed[playerId] = true;
        if (game.committed[0] && game.committed[1]) {
            game.status = GameStatus.RevealPhase;
        }

        emit ChoiceCommited(_gameId, playerId + 1, _hash);
        emit StatusUpdate(_gameId, game.status);
    }

    function revealChoice(uint256 _gameId, string memory _choiceStr) public isGame(_gameId) isPlayer(_gameId) gStatus(_gameId, GameStatus.RevealPhase, errors[4]) {
        Game storage game = games[_gameId];
        uint8 playerId = msg.sender == game.player1 ? 0 : 1;
        require(!game.revealed[playerId], errors[7]);
        require(game.choiceCommits[playerId] == keccak256(abi.encodePacked(_choiceStr)), errors[8]);

        bool pChoice = bytes(_choiceStr).length % 2 == 0;
        game.choices[playerId] = pChoice;
        game.revealed[playerId] = true;
        if (game.revealed[0] && game.revealed[1]) {
            game.status = GameStatus.AwaitingWinner;
        }

        emit ChoiceRevealed(_gameId, playerId + 1, pChoice);
        emit StatusUpdate(_gameId, game.status);
    }

    function announceWinner(uint256 _gameId) public isGame(_gameId) isPlayer(_gameId) gStatus(_gameId, GameStatus.AwaitingWinner, errors[9]) {
        Game storage game = games[_gameId];
        assert(game.revealed[0] && game.revealed[1]);
        assert(game.gameBalance == 2 ether);

        bool choiceP1 = game.choices[0];
        bool choiceP2 = game.choices[1];
        address winner = choiceP1 == choiceP2 ? game.player1 : game.player2;
        require(playerBalances[winner] + game.gameBalance > playerBalances[winner], errors[10]);
        playerBalances[winner] += game.gameBalance;
        game.gameBalance = 0;
        game.status = GameStatus.Completed;

        emit Winner(_gameId, winner, choiceP1, choiceP2);
        emit StatusUpdate(_gameId, game.status);
    }

    function cancelGame(uint256 _gameId) public isGame(_gameId) isPlayer(_gameId) gStatus(_gameId, GameStatus.Initiated, errors[11]) {
        Game storage game = games[_gameId];
        require(msg.sender == game.player1, errors[11]);
        require(playerBalances[game.player1] + 1 ether > playerBalances[game.player1], errors[10]);
        assert(game.gameBalance == 1 ether);

        playerBalances[game.player1] += 1 ether;
        game.gameBalance = 0;
        game.status = GameStatus.Cancelled;
        emit StatusUpdate(_gameId, game.status);
    }

    function withdraw() public {
        uint256 b = playerBalances[msg.sender];
        playerBalances[msg.sender] = 0;
        emit Withdrawal(msg.sender);
        payable(msg.sender).transfer(b);
    }

    function getGameStatus(uint256 _gameId) public view isGame(_gameId) returns (GameStatus status) {
        return games[_gameId].status;
    }

    function getBalance() public view returns (uint256) {
        return playerBalances[msg.sender];
    }

    function getContractBalance() public view returns (uint256) {
        require(msg.sender == contractOwner);
        return address(this).balance;
    }
}
