// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {Test} from "forge-std/Test.sol";
import {Script} from "forge-std/Script.sol";
import {GooSitter} from "../src/GooSitter.sol";

/// @author Philippe Dumonet <https://github.com/philogy>
contract DeployGooSitter is Script, Test {
    function run() external {
        uint256 deployKey = vm.envUint("MANAGER_PRIV_KEY");
        vm.startBroadcast(deployKey);
        new GooSitter(vm.addr(deployKey), vm.envAddress("COLD_WALLET"));
        vm.stopBroadcast();
    }
}
