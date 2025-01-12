// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "../lib/foundry-devops/src/DevOpsTools.sol";


contract CreateSubscription is Script{

    function createSubscriptionUsingConfig() public returns(uint64){
         HelperConfig helperConfig = new HelperConfig();
        ( , , address vrfCordinator, , , , ,uint256 deployerKey) = helperConfig.activeNetworkConfig();
        return createSubscription(vrfCordinator, deployerKey);
    }

    function createSubscription( address vrfCordinator, uint256 deployerKey ) public returns(uint64){
        console.log("Create subscription on chainId: ", block.chainid);
        vm.startBroadcast(deployerKey);
        uint64 subId = VRFCoordinatorV2Mock(vrfCordinator).createSubscription();

        vm.stopBroadcast();
        console.log("Your Subscription id is:", subId);
        console.log("Update your subscritpion id in HelperConfig.s.sol");
        return subId;

    }
    

    function run() external returns(uint64){
        return createSubscriptionUsingConfig();
    }
}


contract FundSubscription is Script{
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSrbscriptionUsingConfig() public {
         HelperConfig helperConfig = new HelperConfig();

        (,,address vrfCoordinator ,, uint64 subId,, address link, uint256 deployerKey) = helperConfig.activeNetworkConfig();

        fundSubscription(vrfCoordinator, subId, link, deployerKey);
        
    }
       function fundSubscription(address vrfCoordinator, uint64 subId, address link, uint256 deployerKey)  public{
        console.log("Funding subscription: ", subId);
        console.log("Using vrfCordinator: ", vrfCoordinator);
        console.log("On ChainID: ", block.chainid);

        if(block.chainid == 31337){
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(subId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else{
            vm.startBroadcast(deployerKey);
            LinkToken(link).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subId));
            vm.stopBroadcast();
        }

    }

    function run() external{
        fundSrbscriptionUsingConfig();
    }
}

contract AddConsumer is Script{

    function addConsumer(address raffle, address vrfCoordinator, uint64 subId, uint256 deployerKy) public {
        console.log("adding consumer contract: ",raffle);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("on ChainID: ", block.chainid);

        vm.startBroadcast(deployerKy);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId, raffle);
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address raffle)  public {
         HelperConfig helperConfig = new HelperConfig();

        (,,address vrfCoordinator ,, uint64 subId,,, uint256 deployerKey) = helperConfig.activeNetworkConfig();

        addConsumer(raffle, vrfCoordinator
        , subId, deployerKey);
    }

    function run() external  {
        address raffle = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        ); 

        addConsumerUsingConfig(raffle);
        
    }
}