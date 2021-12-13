# Blockchain Matching Pennies Game

NOTE The Instructions below are a bit wordy, since they're taken straight from the Contract Design section of the report submitted for the relevant assignment at University. The full report is included in the repo in case you want to find out more info.


## Contract Design/ Usage Instructions

The implemented contract describes a matching pennies game played by 2 different ethereum accounts over the blockchain, where each account wagers 1 ether to join the game, and the winner wins the loser's ether. The game's execution 'phases' follow the steps of a cryptographic commitment scheme, where players must first commit encrypted representations of their choices before revealing them to each other afterwards - only after further commits are blocked \cite{foundationsOfCryptography}. 


Following the structure described above, players must first join the game by calling the "joinGame" function, passing their commitment in a transaction with a 1 ether value. After both players join, players can then call the "revealValue" function to reveal their respective values, where the contract makes sure that the hash of the revealed value matches up with the commitment made by the same player earlier. It also ensures that the commitment value passed in the reveal phase matches up with that originally committed by that player.


After both players successfully reveal their votes, another function - "calculateWinner" - can then be called to calculate the winner, whose winnings are added to a mapping representing balances held by different addresses. The winner can then call a function to withdraw their winnings afterwards, a choice which follows the "pull over push" design pattern, and prevents possible gas issues that could arise from making a transfer during a wider transaction.


The primary motivating factor behind the design choices outlined above is the prevention of cheating strategies by adversarial players, which is achieved in a variety of methods. Firstly, the usage of a commitment scheme ensures the confidentiality of the committed values during the commitment phase. Afterwards, the outcome of the game cannot be altered, since further commitments are blocked. Moreover, a value can only be revealed by the account that made the respective commitment, thus preventing manipulation by malicious parties.


Furthermore, rather than restricting the number of valid options to a binary "head" or "tails" - thus invalidating the use of a commitment scheme - players can use any string for the value. This prevents adversaries from comparing the commitments made by other players with a list of what would otherwise be the only two possible hashes. The value's length is then used for the comparison, where the even lengths are "heads" and odd lengths are "tails".

The motivation behind that choice described above over a more obvious option -  such as using an integer value - was partially motivated by usability. It was noted that if a user were to externally hash their value using an online tool to come up with their commitment value, it would produce the hash of a string representation of the passed in data, even if it was numerical. Furthermore, the use of even and odd lengths allows the program to accept any input string from the user, prevent a whole class of errors that could arise from accepting a commitment hash of what would later turn out to be an illegal string. 


Finally, the contract also contains a function, "resetFailedGameState", for handling resetting the state in order to start a new game in case both players attempt to grief, a scenario described further in section \ref{sec:security}. This resets the game-specific storage variables kept in the contract, which are a mapping of addresses to their commitments, an array of player addresses, and an array of vote structs. Vote structs keep track of the revealed values, where each "Vote" contains the length of the value string as well as the player who committed that value. This state is reset by first iterating over the mappings kept between player addresses and their commitments and setting the respective values to zero, and then resetting the player addresses array, votes array and revealPhaseEndTime using the "delete" keyword.
