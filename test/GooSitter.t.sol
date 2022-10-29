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
    address owner = vm.addr(2);

    function setUp() public {
        goo = new MockERC20();
        gobblers = new MockArtGobblers(goo);
        vm.prank(owner);
        sitter = new GooSitter(address(gobblers), address(goo), manager);
    }

    function testInitialOwner() public {
        assertEq(sitter.owner(), owner);
    }

    function testNotManagerBuy(address _caller) public {
        vm.assume(_caller != manager);
        vm.prank(_caller);
        vm.expectRevert(GooSitter.NotManager.selector);
        sitter.buyGobbler(100e18);
    }

    function testFailCallValueBuy(uint256 _amount) public {
        vm.assume(_amount > 0);
        vm.deal(manager, _amount);
        vm.prank(manager);
        sitter.buyGobbler{value: _amount}(100e18);
    }

    function testManagerCanBuy() public {
        uint256 maxPrice = 3000e18;
        gobblers.setMaxPrice(maxPrice);
        vm.prank(manager);
        vm.expectCall(
            address(gobblers),
            abi.encodeCall(IArtGobblers.mintFromGoo, (maxPrice, true))
        );
        sitter.buyGobbler(maxPrice);
    }

    function testGooConsolidation(uint256 _mintAmount) public {
        goo.mint(address(sitter), _mintAmount);
        sitter.consolidateGoo();
        assertEq(gobblers.gooBalance(address(sitter)), _mintAmount);
        assertEq(goo.balanceOf(address(sitter)), 0);
    }

    function testFailNotOwnerWithdraw(address _withdrawer) public {
        vm.assume(_withdrawer != owner);
        vm.prank(_withdrawer);
        sitter.withdraw(_withdrawer, new uint256[](0));
    }

    function testOwnerWithdraw(address _recipient, uint256 _gooAmount) public {
        vm.assume(_recipient != address(0));

        // setup Gobblers
        uint256[] memory tokens = new uint256[](5);
        for (uint256 i; i < 5; ) {
            tokens[i] = gobblers.mint(address(sitter));
            assertEq(gobblers.ownerOf(tokens[i]), address(sitter));
            // prettier-ignore
            unchecked { ++i; }
        }

        // setup GOO
        goo.mint(address(sitter), _gooAmount);
        sitter.consolidateGoo();
        assertEq(gobblers.gooBalance(address(sitter)), _gooAmount);
        assertEq(goo.balanceOf(address(sitter)), 0);

        vm.prank(owner);
        sitter.withdraw(_recipient, tokens);

        for (uint256 i; i < 5; ) {
            assertEq(gobblers.ownerOf(tokens[i]), _recipient);
            // prettier-ignore
            unchecked { ++i; }
        }
        assertEq(goo.balanceOf(_recipient), _gooAmount);
    }
}
