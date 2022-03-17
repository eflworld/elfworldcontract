pragma solidity ^0.8.0;
// SPDX-License-Identifier: MIT

interface IAddressManager {
    function getAddress(string calldata _target) external view returns (address);
}