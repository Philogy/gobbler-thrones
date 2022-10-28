// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {Test} from "forge-std/Test.sol";
import {GooSitter} from "../src/GooSitter.sol";
import {MockArtGobblers} from "./mock/MockArtGobblers.sol";
import {MockERC20} from "./mock/MockERC20.sol";
import {IArtGobblers} from "../src/IArtGobblers.sol";

/// @author Philippe Dumonet <https://github.com/philogy>
contract GooSitterTest is Test {
    MockERC20 goo;
    MockArtGobblers gobblers;
    GooSitter sitter;

    address manager = vm.addr(1);
    address user = vm.addr(2);
    address attacker = vm.addr(3);

    function setUp() public {
        goo = new MockERC20();
        gobblers = new MockArtGobblers(goo);
        sitter = new GooSitter(address(gobblers), address(goo), manager);
    }

    function testFailNotManagerBuy(address _caller) external {
        vm.assume(_caller != manager);
        vm.prank(_caller);
        sitter.buyGobbler(100e18);
    }

    function testFailCallValueBuy(uint256 _amount) external {
        vm.assume(_amount > 0);
        vm.deal(manager, _amount);
        vm.prank(manager);
        sitter.buyGobbler{value: _amount}(100e18);
    }

    function testManagerCanBuy(uint256 _maxPrice) external {
        vm.prank(manager);
        vm.expectCall(
            address(gobblers),
            abi.encodeCall(IArtGobblers.mintFromGoo, (_maxPrice, true))
        );
        sitter.buyGobbler(_maxPrice);
    }
}
