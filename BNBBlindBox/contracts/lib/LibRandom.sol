// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibRandom {
    function randomRole(uint256 tokenId, address addr) internal view returns (uint256) {
        uint256 seed = generateSeed(tokenId, addr);
        return (seed - ((seed / 10000) * 10000));
    }

    function generateSeed(uint256 tokenId, address to) private view returns (uint256 seed) {
        seed = uint256(keccak256(abi.encodePacked(
            block.difficulty,
            block.number,
            block.timestamp,
            tokenId,
            to
        )));
    }
}