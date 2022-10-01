// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IArtGobblers} from "./IArtGobblers.sol";

/// @author Philogy <https://github.com/Philogy>
contract VirtualGoo {
    string public constant name = "Virtual GOO";
    string public constant symbol = "vGOO";

    IArtGobblers public immutable artGobblers;

    constructor(address _artGobblers) {
        artGobblers = IArtGobblers(_artGobblers);
    }

    function balanceOf(address _addr) external view returns (uint256) {
        return artGobblers.gooBalance(_addr);
    }
}
