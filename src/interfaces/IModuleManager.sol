// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

enum Operation {
    Call,
    DelegateCall
}

/// @author Based on [Gnosis Safe's ModuleManager](https://github.com/safe-global/safe-contracts/blob/da66b45ec87d2fb6da7dfd837b29eacdb9a604c5/contracts/base/ModuleManager.sol)
interface IModuleManager {
    function execTransactionFromModule(
        address to,
        uint256 value,
        bytes memory data,
        Operation operation
    ) external returns (bool success);

    function execTransactionFromModuleReturnData(
        address to,
        uint256 value,
        bytes memory data,
        Operation operation
    ) external returns (bool success, bytes memory returnData);

    function isModuleEnabled(address module) external view returns (bool);
}
