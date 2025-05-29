// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {TinyLend} from "../src/TinyLend.sol";
import {Create2} from "@openzeppelin/utils/Create2.sol";
import {console} from "forge-std/console.sol";

contract DeployScript is Script {
    // salt for create2 deployment - can be any bytes32 value
    // this will be the same across all chains
    bytes32 public constant SALT = keccak256(bytes("hold me closer tiny lender"));

    function run() public {
        // get deployer private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // deploy using create2
        bytes memory bytecode = type(TinyLend).creationCode;
        address tinyLend = Create2.deploy(
            0, // amount of ETH to send
            SALT,
            bytecode
        );

        vm.stopBroadcast();

        console.log("Successfully deployed TinyLend to:", tinyLend);
    }
}

// To deploy and verify on Arbitrum Sepolia:
//forge script script/Deploy.s.sol:DeployScript --fork-url $ARBITRUM_SEPOLIA_RPC_URL --broadcast --verify --verifier-url $ETHERSCAN_API_KEY --etherscan-api-key $ARBISCAN_API_KEY -vvvv
