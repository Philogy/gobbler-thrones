// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {Owned} from "@solmate/auth/Owned.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IArtGobblers} from "./interfaces/IArtGobblers.sol";

/// @author Philippe Dumonet <https://github.com/philogy>
contract GooSitter is Owned {
    IArtGobblers internal constant gobblers = IArtGobblers(0x60bb1e2AA1c9ACAfB4d34F71585D7e959f387769);
    IERC20 internal constant goo = IERC20(0x600000000a36F3cD48407e35eB7C5c910dc1f7a8);
    address internal immutable manager;

    bool internal constant BUY_GOBBLER_WITH_VIRTUAL = true;

    error NotManager();
    error FailedCustomCall(bytes errorData);

    constructor(address _manager, address _initialOwner) Owned(_initialOwner) {
        manager = _manager;
    }

    /// @dev Transfers gobblers and virtual GOO to `_recipient`.
    /// @notice Does **not** use `safeTransferFrom` so be sure double-check `_recipient` before calling.
    function withdraw(
        address _recipient,
        uint256[] calldata _gobblerIds,
        uint256 _gooAmount
    ) external onlyOwner {
        uint256 gobblerCount = _gobblerIds.length;
        for (uint256 i; i < gobblerCount; ) {
            gobblers.transferFrom(address(this), _recipient, _gobblerIds[i]);
            // prettier-ignore
            unchecked { ++i; }
        }
        if (_gooAmount == type(uint256).max) _gooAmount = gobblers.gooBalance(address(this));
        gobblers.removeGoo(_gooAmount);
        goo.transfer(_recipient, _gooAmount);
    }

    /// @dev Allow `owner` to call any contract, necessary to claim certain airdrops.
    function doCustomCall(address _target, bytes calldata _calldata) external payable onlyOwner {
        (bool success, bytes memory errorData) = _target.call{value: msg.value}(_calldata);
        if (!success) revert FailedCustomCall(errorData);
    }

    /// @dev Allows the `manager` to buy a gobbler on your behalf.
    /// @dev Not actually payable, but callvalue check is done more cheaply in assembly.
    function buyGobbler(uint256 _maxPrice) external payable {
        // Copy immutables locally since they're not supported in assembly.
        address manager_ = manager;
        address gobblers_ = address(gobblers);
        assembly {
            // Store `mintFromGoo(uint256,bool)` selector.
            mstore(0x00, 0xc9bddac6)
            // Prepare `mintFromGoo` parameters.
            mstore(0x20, _maxPrice)
            mstore(0x40, BUY_GOBBLER_WITH_VIRTUAL)

            // Call optimistically and do `msg.sender` auth require after.
            let success := call(gas(), gobblers_, 0, 0x1c, 0x44, 0x00, 0x00)

            // If `msg.sender != manager` sub result will be non-zero.
            let authDiff := sub(caller(), manager_)
            if or(or(authDiff, callvalue()), iszero(success)) {
                if authDiff {
                    // Revert `NotManager()`.
                    mstore(0x00, 0xc0fc8a8a)
                    revert(0x1c, 0x04)
                }
                let revSize := mul(iszero(callvalue()), returndatasize())
                returndatacopy(0x00, 0x00, revSize)
                revert(0x00, revSize)
            }

            // End here to ensure we can safely leave the free memory pointer.
            stop()
        }
    }

    /// @dev Doesn't send GOO anywhere so it's safe for anyone to be able to call.
    function consolidateGoo() external {
        gobblers.addGoo(goo.balanceOf(address(this)));
    }
}
