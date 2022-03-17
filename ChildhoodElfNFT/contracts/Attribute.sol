// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;
import './lib/LibRandom.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol';
import '../node_modules/elf-contracts/contracts/lib/LibRole.sol';

contract Attribute is Initializable {
    using SafeMathUpgradeable for uint32;
    uint16[] public roleTypes;
    mapping(uint256 => LibRole.RoleAttrsStruct) private defaultRoleAttrs;
    mapping(uint16 => string) public metaURIConf;
    mapping(uint16 => string) public metaURIFemale;
    mapping(uint16 => LibRole.Rarity) public rarity;
    mapping(uint16 => bool) public roleAttrsIsInit;
    mapping(uint16 => LibRole.Type) public types;
    mapping(LibRole.Rarity => uint16[]) private rarityMapRoleType;
    // tokenId => RoleAttrsStruct
    mapping(uint256 => LibRole.RoleAttrsStruct) private roleAttrs;
    event CreateRole(address indexed creator, uint16 roleType, uint256 tokenId, LibRole.Gender gender, uint256 fatherId, uint256 motherId, address fatherAddress, address motherAddress);
    event SetLevel(uint256 tokenId, uint16 level);

    function _addRoleDefaultAttrs(LibRole.RoleAttrsStruct[] memory _defaultRoleAttrs,  string[] memory _metaURIs, LibRole.Rarity[] memory raritys, LibRole.Type[] memory _types) internal {
        for (uint i = 0; i < _defaultRoleAttrs.length; i++) {
            require(!roleAttrsIsInit[_defaultRoleAttrs[i].roleType], 'ELFRoleChildhood: has been initialized');
            roleAttrsIsInit[_defaultRoleAttrs[i].roleType] = true;
            roleTypes.push(_defaultRoleAttrs[i].roleType);
            defaultRoleAttrs[_defaultRoleAttrs[i].roleType] = _defaultRoleAttrs[i];
            metaURIConf[_defaultRoleAttrs[i].roleType] = _metaURIs[i];
            metaURIFemale[_defaultRoleAttrs[i].roleType] = _metaURIs[i + _defaultRoleAttrs.length];
            rarity[_defaultRoleAttrs[i].roleType] = raritys[i];
            types[_defaultRoleAttrs[i].roleType] = _types[i];
        }
        _init_rarityMapRoleType(_defaultRoleAttrs);
    }

    function _init_rarityMapRoleType(LibRole.RoleAttrsStruct[] memory _defaultRoleAttrs) internal {
        for (uint16 i = 0; i < _defaultRoleAttrs.length; i++) {
            rarityMapRoleType[rarity[_defaultRoleAttrs[i].roleType]].push(_defaultRoleAttrs[i].roleType);
        }
    }

    function setRoleRandomAttrs(uint256 tokenId, uint256 fatherId, uint256 motherId) internal {
        uint256 randomNumber = LibRandom.randomAttr(tokenId, fatherId, motherId);
        bool isAdd = false;
        if (randomNumber > 1000) {
            randomNumber =  SafeMathUpgradeable.sub(randomNumber, 1000);
            isAdd = true;
        }

        LibRole.RoleAttrsStruct memory roleAttrsMemory = roleAttrs[tokenId];

        uint256 STANUM = SafeMathUpgradeable.div(roleAttrsMemory.STA.mul(randomNumber), 10000);
        uint256 STRNUM = SafeMathUpgradeable.div(roleAttrsMemory.STR.mul(randomNumber), 10000);
        uint256 AGINUM = SafeMathUpgradeable.div(roleAttrsMemory.AGI.mul(randomNumber), 10000);
        uint256 INTNUM = SafeMathUpgradeable.div(roleAttrsMemory.INT.mul(randomNumber), 10000);

        if (isAdd) {
            roleAttrs[tokenId].STA = uint32(roleAttrsMemory.STA.add(STANUM));
            roleAttrs[tokenId].STR = uint32(roleAttrsMemory.STR.add(STRNUM));
            roleAttrs[tokenId].AGI = uint32(roleAttrsMemory.AGI.add(AGINUM));
            roleAttrs[tokenId].INT = uint32(roleAttrsMemory.INT.add(INTNUM));

        } else {
            roleAttrs[tokenId].STA = uint32(roleAttrsMemory.STA.sub(STANUM));
            roleAttrs[tokenId].STR = uint32(roleAttrsMemory.STR.sub(STRNUM));
            roleAttrs[tokenId].AGI = uint32(roleAttrsMemory.AGI.sub(AGINUM));
            roleAttrs[tokenId].INT = uint32(roleAttrsMemory.INT.sub(INTNUM));
        }
        calculateProperties(tokenId);
    }


    function calculateProperties(uint256 tokenId) internal {
        LibRole.RoleAttrsStruct memory roleAttrsMemory = roleAttrs[tokenId];
        roleAttrs[tokenId].DAM = uint32(roleAttrsMemory.INT.mul(2));
        roleAttrs[tokenId].ARM = uint32(roleAttrsMemory.STR);
        roleAttrs[tokenId].CRE = uint32(roleAttrsMemory.STR.div(2));
        roleAttrs[tokenId].HP = uint32(roleAttrsMemory.STA.mul(10));
        roleAttrs[tokenId].HIT = uint32(roleAttrsMemory.STA.div(2));
        roleAttrs[tokenId].CRI = uint32(roleAttrsMemory.AGI.div(2));
        roleAttrs[tokenId].SPE = uint32(roleAttrsMemory.AGI);
        roleAttrs[tokenId].ADF = uint32(roleAttrsMemory.INT);
        roleAttrs[tokenId].EVA = uint32(SafeMathUpgradeable.div(roleAttrsMemory.INT.mul(4), 10));
        uint256 ATK = roleAttrs[tokenId].DAM.add(roleAttrs[tokenId].ARM);
        ATK = SafeMathUpgradeable.add(ATK, uint32(roleAttrs[tokenId].HP.mul(1)).div(10));
        ATK = SafeMathUpgradeable.add(ATK, roleAttrs[tokenId].SPE);
        ATK = SafeMathUpgradeable.add(ATK, roleAttrs[tokenId].HIT.mul(2));
        ATK = SafeMathUpgradeable.add(ATK, uint32(roleAttrs[tokenId].EVA.mul(24)).div(10));
        ATK = SafeMathUpgradeable.add(ATK, roleAttrs[tokenId].CRI.mul(2));
        ATK = SafeMathUpgradeable.add(ATK, roleAttrs[tokenId].CRE.mul(2));
        roleAttrs[tokenId].ATK = uint32(ATK);
    }

    function _createNewRole(uint256 tokenId, address creator, uint16 role, LibRole.Gender gender, uint256 fatherId, uint256 motherId, address fatherAddress, address motherAddress) internal {
        roleAttrs[tokenId] = defaultRoleAttrs[role];
        roleAttrs[tokenId].roleType = role;
        roleAttrs[tokenId].gender = gender;
        roleAttrs[tokenId].fatherId = fatherId;
        roleAttrs[tokenId].motherId = motherId;
        roleAttrs[tokenId].fatherAddress = fatherAddress;
        roleAttrs[tokenId].motherAddress = motherAddress;
        setRoleRandomAttrs(tokenId, fatherId, motherId);
        emit CreateRole(creator, roleAttrs[tokenId].roleType, tokenId, roleAttrs[tokenId].gender, fatherId, motherId, fatherAddress, motherAddress);
    }

    function _getRoleAttrs(uint256 tokenId) internal view returns (LibRole.RoleAttrsStruct memory) {
        return roleAttrs[tokenId];
    }

    function _tokenURI(uint256 tokenId) internal view returns (string memory) {
        LibRole.RoleAttrsStruct memory role = _getRoleAttrs(tokenId);
        if (role.gender == LibRole.Gender.FEMALE) {
            return metaURIFemale[role.roleType];
        }
        return metaURIConf[role.roleType];
    }

    function _setLevel(uint256 tokenId, uint16 level) internal {
        roleAttrs[tokenId].level = level;
        emit SetLevel(tokenId, level);
    }

    function getDefaultRoleAttrs(uint16 roleType) public view returns (LibRole.RoleAttrsStruct memory roleAttribute) {
        roleAttribute = defaultRoleAttrs[roleType];
    }
    function getRoleTypeArrByRarity(LibRole.Rarity _rarity) public view returns (uint16[] memory) {
        return rarityMapRoleType[_rarity];
    }
}