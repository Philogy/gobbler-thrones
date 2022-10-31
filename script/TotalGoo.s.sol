// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {Test} from "forge-std/Test.sol";
import {Script} from "forge-std/Script.sol";
import {TotalGoo} from "../src/TotalGoo.sol";

/// @author Philippe Dumonet <https://github.com/philogy>
contract DeployTotalGoo is Script, Test {
    function run() external {
        uint256 deployKey = vm.envUint("VANITY_PRIV_KEY");
        vm.startBroadcast(deployKey);
        TotalGoo totalGoo = new TotalGoo();
        vm.stopBroadcast();
    }
}
