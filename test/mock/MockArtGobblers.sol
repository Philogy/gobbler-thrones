// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {ERC721} from "solmate/tokens/ERC721.sol";
import {MockERC20} from "./MockERC20.sol";

/// @author Philippe Dumonet <https://github.com/philogy>
contract MockArtGobblers is ERC721 {
    uint256 __someState;

    MockERC20 internal immutable goo;

    mapping(address => uint256) public gooBalance;
    uint256 public totalSupply;
    uint256 public maxPrice;

    error PriceExceededMax();

    constructor(MockERC20 _goo) ERC721("Mock ArtGobblers", "MAGOO") {
        goo = _goo;
    }

    function setMaxPrice(uint256 _newMaxPrice) external {
        maxPrice = _newMaxPrice;
    }

    function addGoo(uint256 _amount) external {
        goo.burn(msg.sender, _amount);
        gooBalance[msg.sender] += _amount;
    }

    function removeGoo(uint256 _amount) external {
        goo.mint(msg.sender, _amount);
        gooBalance[msg.sender] -= _amount;
    }

    function tokenURI(uint256) public pure override returns (string memory) {
        return "lmao, no uri";
    }

    function mint(address _recipient) external returns (uint256 newId) {
        unchecked {
            _mint(_recipient, (newId = ++totalSupply));
        }
    }

    function mintFromGoo(uint256 _maxPrice, bool _useVirtualBalance)
        external
        returns (uint256 gobblerId)
    {
        if (_maxPrice > maxPrice) revert PriceExceededMax();
        __someState++;
        gobblerId = uint256(
            keccak256(abi.encode(_maxPrice, _useVirtualBalance))
        );
    }
}
