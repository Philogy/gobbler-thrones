// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Test} from "forge-std/Test.sol";
import {GnosisSafeTest} from "./utils/GnosisSafe.t.sol";
import {MockArtGobblers} from "./mock/MockArtGobblers.sol";
import {MockERC20} from "./mock/MockERC20.sol";
import {IArtGobblers} from "../src/interfaces/IArtGobblers.sol";

import {GnosisSafe} from "@gnosis-safe/GnosisSafe.sol";
import {Enum} from "@gnosis-safe/common/Enum.sol";
import {GobblerBuyerModule} from "../src/GobblerBuyerModule.sol";

/// @author philogy <https://github.com/philogy>
contract GobblerBuyerModuleTest is Test, GnosisSafeTest {
    address internal defaultUser = vm.addr(1);
    address[] internal defaultOwners;
    GobblerBuyerModule internal buyerModule;
    MockERC20 goo = MockERC20(0x600000000a36F3cD48407e35eB7C5c910dc1f7a8);
    MockArtGobblers gobblers = MockArtGobblers(0x60bb1e2AA1c9ACAfB4d34F71585D7e959f387769);

    uint256 internal constant DEFAULT_NONCE = 0;

    event BuyerSet(address indexed safe, address indexed buyer);
    event EnabledModule(address module);

    function setUp() public {
        MockERC20 fakeGoo = new MockERC20();
        vm.etch(address(goo), address(fakeGoo).code);
        MockArtGobblers fakeGobblers = new MockArtGobblers(goo);
        vm.etch(address(gobblers), address(fakeGobblers).code);
        gobblers.setMaxPrice(type(uint256).max);

        defaultOwners = new address[](1);
        defaultOwners[0] = defaultUser;
        buyerModule = new GobblerBuyerModule();
    }

    function testSetupBuyerAtDeploy(address _buyer) public {
        GnosisSafe multisig = GnosisSafe(
            payable(
                deploySafe(
                    defaultOwners,
                    1,
                    address(buyerModule),
                    abi.encodeCall(buyerModule.setupGobblerBuyer, (_buyer)),
                    DEFAULT_NONCE
                )
            )
        );
        assertEq(buyerModule.buyerOf(address(multisig)), _buyer);
        assertTrue(multisig.isModuleEnabled(address(buyerModule)));
    }

    function testAfterDeployEnable() public {
        GnosisSafe multisig = createDefaultMultisig();
        vm.expectEmit(true, true, true, true, address(multisig));
        emit EnabledModule(address(buyerModule));
        callMultisig(multisig, address(multisig), abi.encodeCall(multisig.enableModule, (address(buyerModule))));
        assertTrue(multisig.isModuleEnabled(address(buyerModule)));
    }

    function testSetBuyer(address _buyer) public {
        GnosisSafe multisig = createEnabledMultisig();
        vm.expectEmit(true, true, true, true, address(buyerModule));
        emit BuyerSet(address(multisig), _buyer);
        callMultisig(multisig, address(buyerModule), abi.encodeCall(buyerModule.setBuyer, (_buyer)));
        assertEq(buyerModule.buyerOf(address(multisig)), _buyer);
    }

    function testBuyerCanMint(address _buyer, uint256 _price) public {
        vm.assume(_buyer != address(0));
        GnosisSafe multisig = createEnabledMultisig();
        callMultisig(multisig, address(buyerModule), abi.encodeCall(buyerModule.setBuyer, (_buyer)));
        vm.prank(_buyer);
        vm.expectCall(address(gobblers), abi.encodeCall(IArtGobblers.mintFromGoo, (_price, true)));
        buyerModule.buyFor(address(multisig), _price);
        assertEq(gobblers.lastCaller(), address(multisig));
        assertEq(gobblers.balanceOf(address(multisig)), 1);
    }

    function testNonBuyerCannotMint(
        address _buyer,
        address _notBuyer,
        uint256 _price
    ) public {
        vm.assume(_buyer != _notBuyer);
        vm.assume(_notBuyer != address(0));
        GnosisSafe multisig = createEnabledMultisig();
        callMultisig(multisig, address(buyerModule), abi.encodeCall(buyerModule.setBuyer, (_buyer)));
        vm.prank(_notBuyer);
        vm.expectRevert(GobblerBuyerModule.NotBuyer.selector);
        buyerModule.buyFor(address(multisig), _price);
    }

    function testRemoveAll(uint256 _totalGoo) public {
        GnosisSafe multisig = createEnabledMultisig();
        goo.mint(address(multisig), _totalGoo);
        vm.prank(address(multisig));
        gobblers.addGoo(_totalGoo);
        assertEq(gobblers.gooBalance(address(multisig)), _totalGoo);

        callMultisig(multisig, address(buyerModule), abi.encodeCall(buyerModule.removeAllGoo, ()));
        assertEq(gobblers.gooBalance(address(multisig)), 0);
        assertEq(goo.balanceOf(address(multisig)), _totalGoo);
    }

    function testTransferAll(address _recipient, uint256 _totalGoo) public {
        vm.assume(_recipient != address(0));

        GnosisSafe multisig = createEnabledMultisig();
        goo.mint(address(multisig), _totalGoo);
        vm.prank(address(multisig));
        gobblers.addGoo(_totalGoo);
        assertEq(gobblers.gooBalance(address(multisig)), _totalGoo);

        callMultisig(
            multisig,
            address(buyerModule),
            abi.encodeCall(buyerModule.removeAllGooAndTransferTo, (_recipient))
        );
        assertEq(gobblers.gooBalance(address(multisig)), 0);
        assertEq(goo.balanceOf(address(multisig)), 0);
        assertEq(goo.balanceOf(_recipient), _totalGoo);
    }

    function createEnabledMultisig() internal returns (GnosisSafe multisig) {
        multisig = createDefaultMultisig();
        callMultisig(multisig, address(multisig), abi.encodeCall(multisig.enableModule, (address(buyerModule))));
    }

    function callMultisig(
        GnosisSafe _multisig,
        address _target,
        bytes memory _calldata
    ) internal {
        vm.prank(defaultUser);
        _multisig.execTransaction(
            _target,
            0,
            _calldata,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(0),
            getCallerSignature(defaultUser)
        );
    }

    function createDefaultMultisig() internal returns (GnosisSafe multisig) {
        multisig = GnosisSafe(payable(deploySafe(defaultOwners, 1, address(0), "", DEFAULT_NONCE)));
    }
}
