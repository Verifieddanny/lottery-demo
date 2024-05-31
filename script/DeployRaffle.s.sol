// SPDX-License-Identifier: SEE LICENSE IN LICENSE
import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Raffle} from "../src/Raffle.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";
pragma solidity ^0.8.18;

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig){
        HelperConfig helperConfig = new HelperConfig();
        (
            uint256 entranceFee,
            uint256 interval,
            address vrfCordinator,
            bytes32 keyHash,
            uint64 subscriptionId, 
            uint32 callbackGasLimit,
            address link, 
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        if(subscriptionId == 0){
            CreateSubscription createSubscription = new CreateSubscription();
            subscriptionId = createSubscription.createSubscription(vrfCordinator, deployerKey);


            FundSubscription fundSubscription = new FundSubscription();

            fundSubscription.fundSubscription(vrfCordinator, subscriptionId, link, deployerKey);
        }

        vm.startBroadcast();
        Raffle raffle = new Raffle(entranceFee, interval, vrfCordinator, keyHash, subscriptionId, callbackGasLimit);
        vm.stopBroadcast();
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(raffle), vrfCordinator, subscriptionId, deployerKey);
        return (raffle, helperConfig);

    }


}