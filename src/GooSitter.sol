// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {Owned} from "solmate/auth/Owned.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IArtGobblers} from "./IArtGobblers.sol";

/// @author Philippe Dumonet <https://github.com/philogy>
contract GooSitter is Owned {
    IArtGobblers internal immutable gobblers;
    IERC20 internal immutable goo;
    address internal immutable manager;

    bool internal constant BUY_GOBBLER_WITH_VIRTUAL = true;

    constructor(
        address _gobblers,
        address _goo,
        address _manager
    ) Owned(msg.sender) {
        gobblers = IArtGobblers(_gobblers);
        goo = IERC20(_goo);
        manager = _manager;
    }

    /// @dev Transfers gobblers and virtual GOO to `_recipient`.
    /// @notice Does **not** use `safeTransferFrom` so be sure double-check `_recipient` before calling.
    function withdraw(address _recipient, uint256[] calldata _gobblerIds)
        external
        onlyOwner
    {
        uint256 gobblerCount = _gobblerIds.length;
        for (uint256 i; i < gobblerCount; ) {
            gobblers.transferFrom(address(this), _recipient, _gobblerIds[i]);
            // prettier-ignore
            unchecked { ++i; }
        }
        uint256 totalVirtualGoo = gobblers.gooBalance(address(this));
        gobblers.removeGoo(totalVirtualGoo);
        goo.transfer(_recipient, totalVirtualGoo);
    }

    /// @dev Allows the `manager` to buy a gobbler on your behalf.
    /// @dev Not actually payable, but callvalue check is done more cheaply in assembly.
    function buyGobbler(uint256 _maxPrice) external payable {
        // Copy immutables locally since they're not supported in assembly.
        address manager_ = manager;
        address gobblers_ = address(gobblers);
        assembly {
            // Cheaper revert that consumes all gas upon failure.
            // Writes `mintFromGoo` selector to 0x00 upon success.
            mstore(
                sub(and(eq(caller(), manager_), iszero(callvalue())), 1),
                0xc9bddac6
            )
            // Prepare other arguments.
            mstore(0x20, _maxPrice)
            mstore(0x40, BUY_GOBBLER_WITH_VIRTUAL)
            // We don't care if `mintFromGoo` reverts, just want to attempt buy.
            pop(call(gas(), gobblers_, 0, 0x1c, 0x44, 0x00, 0x00))
            // End here to ensure we can safely leave the free memory pointer.
            stop()
        }
    }

    /// @dev Doesn't send GOO anywhere so it's safe for anyone to be able to call.
    function consolidateGoo() external {
        gobblers.addGoo(goo.balanceOf(address(this)));
    }
}
