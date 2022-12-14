// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {Test} from "forge-std/Test.sol";
import {MockArtGobblers} from "./mock/MockArtGobblers.sol";
import {MockERC20} from "./mock/MockERC20.sol";
import {IArtGobblers} from "../src/interfaces/IArtGobblers.sol";
import {GooSitter} from "../src/GooSitter.sol";

/// @author Philippe Dumonet <https://github.com/philogy>
contract GooSitterTest is Test {
    MockERC20 goo = MockERC20(0x600000000a36F3cD48407e35eB7C5c910dc1f7a8);
    MockArtGobblers gobblers = MockArtGobblers(0x60bb1e2AA1c9ACAfB4d34F71585D7e959f387769);
    GooSitter sitter;

    address manager = vm.addr(1);
    address owner = vm.addr(2);

    function setUp() public {
        MockERC20 fakeGoo = new MockERC20();
        vm.etch(address(goo), address(fakeGoo).code);
        MockArtGobblers fakeGobblers = new MockArtGobblers(goo);
        vm.etch(address(gobblers), address(fakeGobblers).code);
        sitter = new GooSitter(manager, owner);
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
        vm.expectCall(address(gobblers), abi.encodeCall(IArtGobblers.mintFromGoo, (maxPrice, true)));
        sitter.buyGobbler(maxPrice);
    }

    function testRevertingManagerBuy() public {
        uint256 maxPrice = 269e18;
        gobblers.setMaxPrice(maxPrice - 1);
        vm.prank(manager);
        vm.expectCall(address(gobblers), abi.encodeCall(IArtGobblers.mintFromGoo, (maxPrice, true)));
        vm.expectRevert(MockArtGobblers.PriceExceededMax.selector);
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
        sitter.withdraw(_withdrawer, new uint256[](0), type(uint256).max);
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
        sitter.withdraw(_recipient, tokens, type(uint256).max);

        for (uint256 i; i < 5; ) {
            assertEq(gobblers.ownerOf(tokens[i]), _recipient);
            // prettier-ignore
            unchecked { ++i; }
        }
        assertEq(goo.balanceOf(_recipient), _gooAmount);
    }

    function testWithdrawPartial(
        address _recipient,
        uint256 _a,
        uint256 _b
    ) public {
        vm.assume(_recipient != address(0));
        (uint256 deposit, uint256 withdraw) = _a > _b ? (_a, _b) : (_b, _a);
        // prepare test
        goo.mint(address(sitter), deposit);
        sitter.consolidateGoo();
        // withdraw
        vm.prank(owner);
        sitter.withdraw(_recipient, new uint256[](0), withdraw);
        // check end state
        assertEq(gobblers.gooBalance(address(sitter)), deposit - withdraw);
        assertEq(goo.balanceOf(_recipient), withdraw);
    }
}
