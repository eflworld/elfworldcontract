// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibRandom {
    function randomAttr(uint256 tokenId, uint256 fatherId, uint256 motherId) internal view returns (uint256) {
        uint256 seed = generateSeed(tokenId, fatherId, motherId);
        return (seed - ((seed / 2000) * 2000));
    }

    function generateSeed(uint256 tokenId, uint256 fatherId, uint256 motherId) private view returns (uint256 seed) {
        seed = uint256(keccak256(abi.encodePacked(
            block.difficulty,
            block.number,
            block.timestamp,
            tokenId,
            fatherId,
            motherId
        )));
    }
}