// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import { Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";


contract TestRaffl is Test {
   Raffle raffle;
   HelperConfig helperConfig;

    event EnteredRaffled(address indexed player);


    address public PLAYER= makeAddr('player');
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    uint256 entranceFee;
    uint256 interval;
    address vrfCordinator;
    bytes32 keyHash;
    uint64 subscriptionId; 
    uint32 callbackGasLimit;
    address link;
   function setUp()  external {
    
   DeployRaffle deployRaffle = new DeployRaffle();

   (raffle, helperConfig) = deployRaffle.run();

    (
        entranceFee,
        interval,
        vrfCordinator,
        keyHash,
        subscriptionId, 
        callbackGasLimit,
        link,
        
    ) = helperConfig.activeNetworkConfig();
    vm.deal(PLAYER, STARTING_USER_BALANCE);
   }

    function testRaffleIntitialziedState() public view {
        // assertEq(raffle.getRaffleState(), Raffle.RaffleState.OPEN);
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWhenNoteEnoughETHSent() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle_NotEnoughETh.selector);
        raffle.enterRaffle();
    }
    function testPlayersRegisteredAreIn() public{
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEnteredEvent() public{
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffled(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCantEnterRaffleWhenCalculating() public  raffleEnteredAndTimePassed{
        raffle.peformUpkeep("");

        vm.expectRevert(Raffle.Raffle_RaffleNotOpen.selector);
        vm.prank(PLAYER);
        vm.deal(PLAYER, 30 ether);
        raffle.enterRaffle{value: entranceFee}();

    }
    
    function testCheckUpkeepReturnsFalseIfNoBlance() public{
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        console.log(upkeepNeeded, "upkeepNeeded");
        console.log(!upkeepNeeded, "!upkeepNeeded");

        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnFalseWhenIsNotOpenState() public raffleEnteredAndTimePassed{
        raffle.peformUpkeep("");

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(upkeepNeeded == false);
        // assertFalse(upkeepNeeded == true);
    }
    function testCheckUpkeepReturnFalseWhenTimeHasNotElapsed() public{
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");


        assertFalse(upkeepNeeded == true);


    }

    function testCheckUpkeepReturnsTrueWhenALlConditionsAreMet() public raffleEnteredAndTimePassed{

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(upkeepNeeded);
    }

    function testPerformKeepRunsIfCheckUpKeepIsTrue() public raffleEnteredAndTimePassed{

        raffle.peformUpkeep("");

    }

    function testPerformKeepRunsIfCheckUpKeepIsfalse() public {
        uint256 currentBalance = 0;
        uint256 players = 0;
        Raffle.RaffleState raffleState = Raffle.RaffleState.OPEN;

        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle_UpkeepNotNeed.selector, currentBalance, players, raffleState
            )
        );

        raffle.peformUpkeep("");
    }

    function testPerformUpkeepUpdatesraffleAndEmitRequestId() public raffleEnteredAndTimePassed{
        vm.recordLogs();
        raffle.peformUpkeep("");
        Vm.Log[] memory entries  = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleState rState = raffle.getRaffleState();

        assert(uint256(requestId) > 0);
        assert(uint256(rState) == 1);
        
    }

    function testFufillRadomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId) public raffleEnteredAndTimePassed skipFork {
        vm.expectRevert("nonexistent request");

        VRFCoordinatorV2Mock(vrfCordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testFulfillRandomWordsPicksAWinnerResetAndSendMoney() public raffleEnteredAndTimePassed skipFork{
        uint256 raffleEnterant = 5;
        uint256 startingIndex = 1;

        for(uint256 i = startingIndex; i < startingIndex + raffleEnterant; i++){
            address player = address(uint160(i));
            hoax(player, STARTING_USER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }
        uint256 price = entranceFee * (raffleEnterant + 1);
        vm.recordLogs();
        raffle.peformUpkeep("");
        Vm.Log[] memory entries  = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        uint256 previousTimeStamp = raffle.getLastTmeStamp();

        VRFCoordinatorV2Mock(vrfCordinator).fulfillRandomWords(uint256(requestId), address(raffle));


        assert(uint256(raffle.getRaffleState())== 0);
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getLengthOfPlayers() == 0);
        assert(previousTimeStamp < raffle.getLastTmeStamp());
        assert(raffle.getRecentWinner().balance == STARTING_USER_BALANCE + price - entranceFee);


    }


    modifier raffleEnteredAndTimePassed {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;        
    }
    modifier skipFork    ()  {
        if(block.chainid != 31337){
            return;
        }
        _;
    }
}