// SPDX-License-Identifier: SEE LICENSE IN LICENSE
import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
pragma solidity ^0.8.18;

contract HelperConfig is Script{
    struct  NetworkConfig {
        uint256 entranceFee; 
        uint256 interval;
        address vrfCordinator;
        bytes32 keyHash;
        uint64 subscriptionId; 
        uint32 callbackGasLimit;
        address link;
        uint256 deployerKey;
    }
    uint256 public constant DEFAULT_ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    NetworkConfig public activeNetworkConfig;

    constructor(){
        if(block.chainid == 11155111){
            activeNetworkConfig = getSepoliaNetworkConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilNetworkConfig();
        }

    }
    function getSepoliaNetworkConfig() public view returns (NetworkConfig memory) {

        return NetworkConfig(
            0.01 ether, 
            30,
            0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
            0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            0, //update with subId
            500000, //500,000 gas!
            0x779877A7B0D9E8603169DdbD7836e478b4624789,
            vm.envUint("PRIVATE_KEY")
        );
        
    }

    function getOrCreateAnvilNetworkConfig() public  returns (NetworkConfig memory){
        if(activeNetworkConfig.vrfCordinator != address(0)){
            return activeNetworkConfig;
        }

        uint96 baseLink = 0.25 ether; //0.25 LINK
        uint96 gaspriceLink = 1e9; // 1 gwei LINK
        vm.startBroadcast();
        VRFCoordinatorV2Mock vrfCoordinatorV2Mock = new VRFCoordinatorV2Mock(baseLink, gaspriceLink);
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();
        return NetworkConfig(
                    0.01 ether, 
                    30,
                    address(vrfCoordinatorV2Mock),
                    0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                    0, //update with subId
                    500000,//500,000 gas!
                    address(linkToken),
                    DEFAULT_ANVIL_PRIVATE_KEY
                );
    }
}


