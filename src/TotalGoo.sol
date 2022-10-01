// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IArtGobblers} from "./IArtGobblers.sol";

/// @author philogy <https://github.com/philogy>
contract TotalGoo {
    string public constant name = "Total GOO (virtual + token)";
    string public constant symbol = "tGOO";

    IArtGobblers public immutable artGobblers;
    IERC20 public immutable goo;

    constructor(address _artGobblers) {
        artGobblers = IArtGobblers(_artGobblers);
        goo = IERC20(IArtGobblers(_artGobblers).goo());
    }

    function balanceOf(address _addr) external view returns (uint256) {
        return artGobblers.gooBalance(_addr) + goo.balanceOf(_addr);
    }
}
