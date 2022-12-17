// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Test} from "forge-std/Test.sol";
import {GnosisSafe} from "@gnosis-safe/GnosisSafe.sol";
import {GnosisSafeProxyFactory} from "@gnosis-safe/proxies/GnosisSafeProxyFactory.sol";

/// @author philogy <https://github.com/philogy>
contract GnosisSafeTest is Test {
    address private _singleton = address(new GnosisSafe());
    GnosisSafeProxyFactory private _safeFactory = new GnosisSafeProxyFactory();

    function deploySafe(
        address[] memory _owners,
        uint256 _threshhold,
        address _to,
        bytes memory _data,
        uint256 _salt
    ) internal returns (address) {
        return
            address(
                _safeFactory.createProxyWithNonce(
                    address(_singleton),
                    abi.encodeCall(
                        GnosisSafe.setup,
                        (_owners, _threshhold, _to, _data, address(0), address(0), 0, payable(0))
                    ),
                    _salt
                )
            );
    }

    function getCallerSignature(address _caller) internal pure returns (bytes memory) {
        return abi.encodePacked(uint256(uint160(_caller)), uint256(0), uint8(1));
    }
}
