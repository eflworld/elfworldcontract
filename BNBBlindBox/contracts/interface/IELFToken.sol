pragma solidity ^0.8.0;
// SPDX-License-Identifier: MIT

interface IELFToken {
    function getReward(address to, uint256 amount) external;
}