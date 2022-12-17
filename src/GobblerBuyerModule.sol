// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {ModuleManager} from "@gnosis-safe/base/ModuleManager.sol";
import {Enum} from "@gnosis-safe/common/Enum.sol";
import {IArtGobblers} from "./interfaces/IArtGobblers.sol";

/// @author philogy <https://github.com/philogy>

contract GobblerBuyerModule {
    address internal immutable THIS;
    address internal constant GOBBLER = 0x60bb1e2AA1c9ACAfB4d34F71585D7e959f387769;

    mapping(address => address) public buyerOf;

    event BuyerSet(address indexed safe, address indexed buyer);

    error NotBuyer();
    error BuyFailed();
    error AttemptedDelegate();

    constructor() {
        THIS = address(this);
    }

    /// @dev Prevent safe from accidentally calling this module via `DelegateCall` operation.
    modifier preventDelegateCall() {
        if (address(this) != THIS) revert AttemptedDelegate();
        _;
    }

    /// @notice Permits `_buyer` to mint new Gobblers with GOO on behalf of safe.
    /// @param _buyer Account allowed to trigger `mintFromGoo` method.
    function setBuyer(address _buyer) external preventDelegateCall {
        buyerOf[msg.sender] = _buyer;
        emit BuyerSet(msg.sender, _buyer);
    }

    /// @dev Always uses virtual balances, GOO tokens are not spendable by the buyer
    function buyFor(address _safe, uint256 _maxPrice) external preventDelegateCall {
        if (buyerOf[_safe] != msg.sender) revert NotBuyer();
        bool success = ModuleManager(_safe).execTransactionFromModule(
            GOBBLER,
            0,
            abi.encodeCall(IArtGobblers.mintFromGoo, (_maxPrice, true)),
            Enum.Operation.Call
        );
        if (!success) revert BuyFailed();
    }
}
