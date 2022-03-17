// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IInvit {
    function isTrade(address addr) external view returns(bool);
    function getInvit(address userAddress) external view returns(address[] memory);
    function appendInvit(address beInvit ,address invit) external returns(bool);
}