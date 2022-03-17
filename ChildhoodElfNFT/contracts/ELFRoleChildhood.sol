// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import '@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';
import './lib/LibRandom.sol';
import './Attribute.sol';
// interface
import './interface/IInvit.sol';
import './interface/IAddressManager.sol';
import '../node_modules/elf-contracts/contracts/interface/IMortgage.sol';

contract ELFRoleChildhood is Attribute, OwnableUpgradeable, ERC721Upgradeable {
    // init function
    using SafeMathUpgradeable for uint;
    uint256 private lastTokenId;
    uint16 private genesisRoleCount;
    IAddressManager public addressManager;
    mapping(address => bool) public isAllowMint;

    function _INIT_ELFRoleChildhood_ (
        IAddressManager _addressManager
    ) public initializer {
        addressManager = _addressManager;
        __ERC721_init('Childhood Elf NFT', 'CEN');
        __Ownable_init();
    }

    function addRoleDefaultAttrs(
        LibRole.RoleAttrsStruct[] memory _defaultRoleAttrs,
        string[] memory metaURI,
        LibRole.Rarity[] memory raritys,
        LibRole.Type[] memory types
    ) external onlyOwner {
        _addRoleDefaultAttrs(_defaultRoleAttrs, metaURI, raritys, types);
    }

    function mintRole(uint16 roleType,  LibRole.Gender gender, address to, uint256 fatherId, uint256 motherId, address fatherAddress, address motherAddress) external {
        require(isAllowMint[_msgSender()], 'ELFRoleChildhood: not allowed to create');
        if (fatherId == 0 && motherId == 0) {
            require(genesisRoleCount < 9000, 'ELFRoleChildhood: Up to 9000 Creation Spirits');
            genesisRoleCount = uint16(SafeMathUpgradeable.add(genesisRoleCount, 1));
        }
        uint256 tokenId = _getNextTokenId();
        _createNewRole(tokenId, to, roleType, gender, fatherId, motherId, fatherAddress, motherAddress);
        _safeMint(to, tokenId);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ELFRoleChildhood: URI query for nonexistent token");
        return _tokenURI(tokenId);
    }

    function getRoleAttrs(uint256 tokenId) public view returns (LibRole.RoleAttrsStruct memory) {
        require(_exists(tokenId), "ELFRoleChildhood: URI query for nonexistent token");
        return _getRoleAttrs(tokenId);
    }

    function _getNextTokenId() internal returns (uint256){
        lastTokenId = lastTokenId.add(1);
        return lastTokenId;
    }

    function setAddressManager(IAddressManager _addressManager) public onlyOwner {
        addressManager = _addressManager;
    }

    function setLevel(uint256 tokenId, uint16 level) external {
        address sender = addressManager.getAddress('ELFGames');
        require(sender == _msgSender(), 'ELFRoleChildhood: sender error');
        require(_exists(tokenId), "ELFRoleChildhood: nonexistent token");
        _setLevel(tokenId, level);
    }

    function setAllowMint(address addr, bool isAllow) external onlyOwner {
        isAllowMint[addr] = isAllow;
    }
    
    function setAllowMintBatch(address[] memory addrs, bool[] memory isAllow) external onlyOwner {
        require(addrs.length == isAllow.length, 'ELFRoleChildhood: length error');
        for (uint8 i = 0; i < addrs.length; i++) {
            isAllowMint[addrs[i]] = isAllow[i];
        }
    }
}