// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

contract RandomNumberGambling is VRFConsumerBaseV2 {
    event Start();
    event Result(bool success);
    event Withdrawn(uint balance);

    mapping(uint => bool) private GameState;
    mapping(uint => uint8) private RandomNumberGame;
    mapping(address => uint) public balance;
    mapping(uint => address) public WinnerScoreBoard;

    address[] public Players;
    address[5] public TopPlayers;

    address immutable i_owner;
    uint immutable i_entrancefee = 0.1 ether;

    /** Chainlink variables **/
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gaslane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    /** **/

    uint RandomNumber;

    uint32 private endAt;

    uint private id = 0;

    constructor(
        address vrfCoordinatorV2,
        bytes32 _gaslane,
        uint64 _subscriptionId,
        uint32 _callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gaslane = _gaslane;
        i_owner = msg.sender;
        i_subscriptionId = _subscriptionId;
        i_callbackGasLimit = _callbackGasLimit;
    }

    /** chainlink function **/
    uint256 public requestId;

    function requestRandom() public {
        requestId = i_vrfCoordinator.requestRandomWords(
            i_gaslane,
            i_subscriptionId,
            3,
            i_callbackGasLimit,
            1
        );
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords)
        internal
        pure
        override
    {
        uint getTheNumber = randomWords[0] % 10;
        uint RandomNumber = getTheNumber;
    }

    /** chainlink function **/

    function random() private view returns (uint) {
        return RandomNumber;
    }

    function timer() private {
        endAt = uint32(block.timestamp + 86400);
    }

    function start_game() public {
        require(msg.sender == i_owner, "Not the owner");
        if (block.timestamp >= endAt) {
            timer();
        }

        uint randomNum = random();
        RandomNumberGame[id] = uint8(randomNum);
        GameState[id] = true;
        id++;
        emit Start();
    }

    function total_game() external view returns (uint) {
        return id;
    }

    function GameStatus(uint _id) external view returns (bool) {
        require(_id <= id, "Game Does Not Exist");
        return GameState[_id];
    }

    function Guess_The_Number(uint8 _number, uint _id)
        external
        payable
        returns (bool)
    {
        require(_id <= id, "Game Does Not Exist");
        require(msg.value >= 0.1 ether, "Not sufficient amount");
        require(GameState[_id] == true, "the game is already over");
        if (_number != RandomNumberGame[_id]) {
            balance[msg.sender] = 0;
            emit Result(false);
            return false;
        } else {
            Players.push(msg.sender);
            balance[msg.sender] = 2 * msg.value;
            WinnerScoreBoard[_id] = msg.sender;
            GameState[_id] = false;
            emit Result(false);
            return true;
        }
    }

    function LeaderBoard() public {
        require(msg.sender == i_owner, "not owner");
        uint first = 0;
        uint second = 0;

        for (uint i = 0; i < Players.length; i++)
            if (balance[Players[i]] > first) {
                TopPlayers[0] = Players[i];
                first = balance[Players[i]];
            }
        for (uint i = 1; i < 5; i++) {
            for (uint j = 0; j < Players.length; j++)
                if (
                    balance[Players[j]] < first && balance[Players[j]] > second
                ) {
                    TopPlayers[i] = Players[j];
                    second = balance[Players[j]];
                }

            first = second;
            second = 0;
        }
    }

    function Check_Winners(address Player) private view returns (bool) {
        for (uint i = 0; i < 5; i++) {
            if (TopPlayers[i] == Player) {
                return true;
            }
        }
        return false;
    }

    function withdraw() external {
        require(block.timestamp > endAt, "wait for until timer is completed");
        require(balance[msg.sender] > 0, "No balance");
        uint _balance = balance[msg.sender] + 0.1 ether;
        require(
            address(this).balance > _balance,
            "not sufficient money in the vault"
        );
        if (Check_Winners(msg.sender)) {
            (bool sent, bytes memory data) = payable(msg.sender).call{
                value: _balance
            }("");
            require(sent, "Failed to send Ether");
            balance[msg.sender] = 0;
            emit Withdrawn(balance[msg.sender]);
        } else {
            (bool sent, bytes memory data) = payable(msg.sender).call{
                value: balance[msg.sender]
            }("");
            require(sent, "Failed to send Ether");
            balance[msg.sender] = 0;
            emit Withdrawn(balance[msg.sender]);
        }
    }
}
