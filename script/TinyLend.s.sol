// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { Script, console } from "forge-std/Script.sol";
import { TinyLend } from "../src/TinyLend.sol";

contract TinyLendScript is Script {
    TinyLend public tinyLend;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        tinyLend = new TinyLend();

        vm.stopBroadcast();
    }
}
