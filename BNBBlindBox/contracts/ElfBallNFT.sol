// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import '../node_modules/elf-contracts/contracts/interface/IAddressManager.sol';
import '../node_modules/elf-contracts/contracts/interface/IInvit.sol';
import '../node_modules/elf-contracts/contracts/interface/IELFRoleChild.sol';
import '../node_modules/elf-contracts/contracts/lib/LibRole.sol';
import './WhiteList.sol';
import './lib/LibRandom.sol';
import './interface/IELFToken.sol';

contract ElfBallNFT is OwnableUpgradeable, ERC721Upgradeable, ReentrancyGuardUpgradeable, WhiteList {
    using SafeMathUpgradeable for uint;
    // const
    string constant private defaultTokenURI = "ipfs://bafkreibzyecw3rjhp4qgcmult2yh6u3u3twqloklvqmhl6uijohuxhyime";
    // attr
    IAddressManager public addressManager;
    uint256 private lastTokenId;
    uint16[] public roleTypes;
    mapping(uint256 => uint256) public probability; // fixed 4
    // events
    event CreateElfball(address indexed creator, uint256 tokenId, string tokenURI);
    event ReferralReward(address indexed invitAddress, address from, uint256 amount);
    function _INIT_ElfBallNFT_(
        IAddressManager _addressManager,
        uint256 startBlock,
        uint16[] memory _roleTypes,
        uint256[] memory probabilitys,
        uint256 price,
        uint256 tokenBallPrice,
        address[] memory whiteListAddress
    ) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __ERC721_init('Elfball NFT', 'EBN');
        _WHITELIST_INIT(
            price,
            tokenBallPrice,
            whiteListAddress, 
            startBlock
        );
        addressManager = _addressManager;
        roleTypes = _roleTypes;
        require(_roleTypes.length == probabilitys.length, 'ElfBallNFT: length error');
        uint256 prevNumber;
        for (uint8 i = 0; i < probabilitys.length; i++) {
            prevNumber = prevNumber.add(probabilitys[i]);
            probability[i + 1] = prevNumber;
        }
    }

    function addWhiteListAmountBatch(address[] memory account) external onlyOwner {
        _addWhiteListAmountBatch(account);
    }
    function addTokenWhiteListAmountBatch(address[] memory account) external onlyOwner {
        _addTokenWhiteListAmount(account);
    }

    function setTokenBallPrice(uint256 price) external onlyOwner {
        _setTokenBallPrice(price);
    }

    function initTokenBallStartBLock(uint256 startBlock) external onlyOwner {
        _initTokenBallStartBLock(startBlock);
    }

    function _getNextTokenId() internal returns (uint256){
        lastTokenId = lastTokenId.add(1);
        return lastTokenId;
    }

    function buyBNBBall (uint8 amount, address invitAddress) external payable nonReentrant {
        require(amount <= 20, 'ElfBallNFT: max amount 20');
        uint256 _s = getAllowBuyAmount(_msgSender());
        uint8 rAmount = amount > _s ? uint8(_s) : amount;
        uint256 checkPayValue = blindConf.price.mul(rAmount);
        require(msg.value >= checkPayValue, 'ElfBallNFT: Wrong payment amount');
        _registerAccount(_msgSender(), invitAddress);
        _mintBox(rAmount, _msgSender());
        _addUsed(_msgSender(), rAmount);
        // invit reward
        uint256 invitReward = checkPayValue.mul(10).div(100);
        address invitAddrResponse = _getInvitAddress(_msgSender());
        address feeTo = addressManager.getAddress('feeTo');
        if (feeTo == address(0)) {
            feeTo = owner();
        }
        if (invitAddrResponse == address(0)) {
            invitReward = 0;
        }
        payable(feeTo).transfer(checkPayValue.sub(invitReward));
        if (invitReward > 0) {
            payable(invitAddrResponse).transfer(invitReward);
        }
        if (msg.value > checkPayValue) {
            payable(_msgSender()).transfer(msg.value.sub(checkPayValue));
        }
    }

    function buyTokenBall (uint8 amount, address invitAddress) external payable nonReentrant {
        require(amount <= 20, 'ElfBallNFT: max amount 20');
        uint256 _s = getAllowBuyAmountToken(_msgSender());
        uint8 rAmount = amount > _s ? uint8(_s) : amount;
        uint256 checkPayValue = blindConfToken.price.mul(rAmount);
        address elfTokenContract = addressManager.getAddress('elfToken');
        uint256 _balance = ERC20Upgradeable(elfTokenContract).balanceOf(_msgSender());
        require(_balance >= checkPayValue, 'ElfBallNFT: balance Insufficient balance');
        _registerAccount(_msgSender(), invitAddress);
        _mintBox(rAmount, _msgSender());
        _addUsedToken(_msgSender(), rAmount);
        // pay
        address feeTo = addressManager.getAddress('feeTo');
        if (feeTo == address(0)) {
            feeTo = owner();
        }
        ERC20Upgradeable(elfTokenContract).transferFrom(_msgSender(), feeTo, checkPayValue);
        // invit Reward
        address invitAddrResponse = _getInvitAddress(_msgSender());
        if (invitAddrResponse != address(0)) {
            uint256 rewardAmount = checkPayValue.div(10);
            IELFToken(elfTokenContract).getReward(invitAddrResponse, rewardAmount);
            emit ReferralReward(invitAddrResponse, _msgSender(), rewardAmount);
        }
    }


    function _getInvitAddress(address userAddress) internal view returns (address) {
        address invitContractAddress = addressManager.getAddress('invit');
        address[] memory invitAddressArray = IInvit(invitContractAddress).getInvit(userAddress);
        if (invitAddressArray.length == 0) {
            return address(0);
        }
        return invitAddressArray[0];
    }

    function _registerAccount(address account, address invitAddress) internal {
        address invitContractAddress = addressManager.getAddress('invit');
        bool isValid = IInvit(invitContractAddress).isTrade(account);
        if (!isValid) {
            IInvit(invitContractAddress).appendInvit(account, invitAddress);
        }
    }

    function blindBoxConf() public view returns (LibWhiteList.BlindConf[] memory) {
        LibWhiteList.BlindConf[] memory conf = new LibWhiteList.BlindConf[](2);
        conf[0] = blindConf;
        conf[1] = blindConfToken;
        return conf;
    }

    function _mintBox(uint8 amount, address to) internal {
        uint256 tokenId;
        if (amount == 1) {
            tokenId = _getNextTokenId();
            _safeMint(_msgSender(), tokenId);
            emit CreateElfball(to, tokenId, defaultTokenURI);
        } else {
            for (uint8 i = 1; i <= amount; i++) {
                tokenId = _getNextTokenId();
                _safeMint(_msgSender(), tokenId);
                emit CreateElfball(to, tokenId, defaultTokenURI);
            }
        }
    }

    function openElfball(uint256 tokenId) public {
        require(ownerOf(tokenId) == _msgSender(),'ElfBallNFT: not owner');
        _burn(tokenId);
        (uint16 role, LibRole.Gender gender) = _randomRole(_msgSender(), tokenId);
        address roleChildContract = addressManager.getAddress('ELFRoleChildhood');
        IELFRoleChild(roleChildContract).mintRole(role, gender, _msgSender(), 0, 0, address(0), address(0));
    }

    function openElfballBatch(uint256[] memory tokenIds) public {
        require(tokenIds.length <= 20,'ElfBallNFT: length error');
        for (uint8 i = 0; i < tokenIds.length; i++) {
            openElfball(tokenIds[i]);
        }
    }

    function tokenURI(uint256 tokenId) public pure override returns (string memory) {
        return defaultTokenURI;
    }

    function _randomRole(address creator, uint256 tokenId) internal view returns (uint16 role, LibRole.Gender gender) {
        uint256 random = LibRandom.randomRole(tokenId, creator);
        for (uint256 i = 0; i < roleTypes.length; i++) {
            if (random <= probability[roleTypes[i]]) {
                role =  roleTypes[i];
                break;
            }
        }
        if (random.mod(2) == 0) {
            gender = LibRole.Gender.FEMALE;
        } else {
            gender = LibRole.Gender.MALE;
        }
    }

    function setAddressManager(IAddressManager _addressManager) public onlyOwner {
        addressManager = _addressManager;
    }


}