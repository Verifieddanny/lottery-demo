// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions




// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

/**
 * @title A sample raffle Contract
 * @author Daniel Nwachukwu
 * @notice This contract is for creating a simple raffle
 * @dev Impements Chainlink VRFv2
 */
contract Raffle is VRFConsumerBaseV2 {

    error Raffle_NotEnoughETh();
    error Raffle_TransferFailed();
    error Raffle_RaffleNotOpen();
    error Raffle_UpkeepNotNeed(uint256 balance, uint256 players, RaffleState raffleState);
    /**Type decelaratins */

    enum RaffleState {
        OPEN,
        CALCULATING       
    }


    uint16 constant REQUEST_CONFIRMATIONS = 3;
    uint32 constant NUM_WORDS = 1;


    uint256 private immutable i_entranceFee;
    /**@dev Duration for Raffle in seconds */
    uint256 private immutable i_interval;
    VRFCoordinatorV2Interface private immutable i_vrfCordinator;
    bytes32 private immutable i_keyHash;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;


    uint256 private s_LastTimeStamp;
    address payable[] private s_players;
    address private s_recentWinner;
    RaffleState private s_raffleState;
    /**Events */
    event EnteredRaffled(address indexed player);
    event PickedWinner(address indexed winner);
    event RequestRaffleWinner(uint256 indexed requestId);


    constructor(uint256 entranceFee, uint256 interval, address vrfCordinator, bytes32 keyHash, uint64 subscriptionId, uint32 callbackGasLimit) 
    VRFConsumerBaseV2(vrfCordinator){
         i_entranceFee = entranceFee;
         i_interval = interval;
         s_LastTimeStamp = block.timestamp;
         i_vrfCordinator = VRFCoordinatorV2Interface(vrfCordinator);
         i_keyHash = keyHash;
         i_subscriptionId = subscriptionId;
         i_callbackGasLimit = callbackGasLimit;
         s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable{
        if(msg.value < i_entranceFee){
            revert Raffle_NotEnoughETh();
        }
        if (s_raffleState != RaffleState.OPEN){
            revert Raffle_RaffleNotOpen();
    }
    s_players.push(payable(msg.sender));

        emit EnteredRaffled(msg.sender);
       
    }

    function checkUpkeep(
        bytes memory /*checkData */
    ) public view  returns (bool upkeepNeeded, bytes memory /*performData*/) {
        bool hasTimePassed = (block.timestamp - s_LastTimeStamp ) >= i_interval;
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance  > 0;
        bool hasPlayers = s_players.length > 0;

        upkeepNeeded = (hasTimePassed && isOpen && hasBalance && hasPlayers);
        return(upkeepNeeded, "0x0");


    }

    
    function peformUpkeep(bytes calldata /*performData */) external {
        (bool upkeepNeeded,) = checkUpkeep("");
        if(!upkeepNeeded){
            revert Raffle_UpkeepNotNeed(
                address(this).balance,
                s_players.length,
                s_raffleState
            );
        }
     
        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId =  i_vrfCordinator.requestRandomWords(
            i_keyHash,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );

        emit RequestRaffleWinner(requestId);
        
    }

    function fulfillRandomWords( uint256 /*requestId*/,
    uint256[] memory randomwWords
    ) internal override {
       uint256 indexOfWinner = randomwWords[0] % s_players.length;
       address payable winner = s_players[indexOfWinner];

       s_recentWinner = winner;
         s_raffleState = RaffleState.OPEN;
       s_players = new address payable[](0);
       s_LastTimeStamp = block.timestamp;

       (bool success,) = winner.call{value: address(this).balance}("");

       if(!success){
        revert Raffle_TransferFailed();
       }

        emit PickedWinner(winner);
        
    }
 
    /**Getter Fns */
    function getEntrancefee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState){
        return s_raffleState;
    }

    function getPlayer(uint index) external view returns (address){
        return s_players[index] ;
    }

    function getRecentWinner() external view returns (address){
        return s_recentWinner;
    }

    function getLengthOfPlayers() external view returns (uint256){
        return s_players.length;
    }
    function getLastTmeStamp() external view returns (uint256){
        return s_LastTimeStamp;
    }
}
