pragma solidity ^0.8.0;
// SPDX-License-Identifier: MIT
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import 'elf-contracts/contracts/interface/IAddressManager.sol';
import 'elf-contracts/contracts/lib/LibMortgage.sol';
import 'elf-contracts/contracts/interface/IELFToken.sol';


contract ELFMortgageandwWthdraw is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeMathUpgradeable for uint;
    uint256 public trainMortgageQuantity;
    IAddressManager public addressManager;
    mapping(address => mapping(uint256 => LibMortgage.mortgageDataStruct)) public trainMortgage;
    mapping(address => mapping(uint256 => address)) public ownerMap;
    uint256 public gamesMortgageELFTAmt;
    mapping(address => mapping(uint256 => LibMortgage.mortgageDataStruct)) public gamesMortgage;
    event TrainMortgageStart(address indexed contractAddress, uint256 tokenId, address account);
    event TrainMortgageCancel(address indexed contractAddress, uint256 tokenId, address account);
    event GamesMortgageStart(address indexed contractAddress, uint256 tokenId, address account);
    event GamesMortgageCancel(address indexed contractAddress, uint256 tokenId, address account);
    event NFTMortgageStart(address indexed contractAddress, uint256 tokenId, address account);
    event NFTMortgageCancel(address indexed contractAddress, uint256 tokenId, address account);

    function _INIT_ELFMortgageandwWthdraw_ (IAddressManager _addressManager, uint256 _trainMortgageQuantity) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        addressManager = _addressManager;
        trainMortgageQuantity = _trainMortgageQuantity;
    }


    function trainMortgageStart(address contractAddress, uint256 tokenId) external nonReentrant {
        if (ownerMap[contractAddress][tokenId] != _msgSender()) {
            require(IERC721Upgradeable(contractAddress).ownerOf(tokenId) == _msgSender(), 'ELFMORT: not owned');
            IERC721Upgradeable(contractAddress).transferFrom(_msgSender(), address(this), tokenId);
            ownerMap[contractAddress][tokenId] = _msgSender();
            emit NFTMortgageStart(contractAddress, tokenId, _msgSender());
        }
        require(trainMortgage[contractAddress][tokenId].startTime == 0 && trainMortgage[contractAddress][tokenId].quantity == 0, 'ELFMORT: in mortgage');
        address tokenContractAddress = addressManager.getAddress('elfToken');
        IERC20Upgradeable(tokenContractAddress).transferFrom(_msgSender(), address(this), trainMortgageQuantity);
        trainMortgage[contractAddress][tokenId].startTime = block.timestamp;
        trainMortgage[contractAddress][tokenId].quantity = trainMortgageQuantity;
        emit TrainMortgageStart(contractAddress, tokenId, _msgSender());
    }

    function trainMortgageCancel(address contractAddress, uint256 tokenId) public nonReentrant {
        require(ownerMap[contractAddress][tokenId] == _msgSender(), 'ELFMORT: not owned');
        LibMortgage.mortgageStatus status = trainMortgageCheck(contractAddress, tokenId);
        if (status == LibMortgage.mortgageStatus.NONE) {
            revert('ELFMORT: not mortgage');
        } else if (status == LibMortgage.mortgageStatus.NORMAL) {
            revert('ELFMORT: in mortgage');
        }
        _releaseToken(contractAddress, tokenId, _msgSender(), 1);
        emit TrainMortgageCancel(contractAddress, tokenId, _msgSender());
    }

    function trainMortgageCheck(address contractAddress, uint256 tokenId) public view returns(LibMortgage.mortgageStatus) {
        LibMortgage.mortgageDataStruct memory datas = trainMortgage[contractAddress][tokenId];
        return _mortgageCheck(datas);
    }

    function gamesMortgageCheck(address contractAddress, uint256 tokenId) public view returns(LibMortgage.mortgageStatus) {
        LibMortgage.mortgageDataStruct memory datas = gamesMortgage[contractAddress][tokenId];
        return _mortgageCheck(datas);
    }

    function queryGamesMortgageBatch(address[] memory contracts, uint256[] memory tokenIds) external view returns (LibMortgage.mortgageDataStruct[] memory) {
        require(contracts.length == tokenIds.length, 'ELFMORT: length error');
        LibMortgage.mortgageDataStruct[] memory datas = new LibMortgage.mortgageDataStruct[](tokenIds.length);
        for (uint i = 0; i < contracts.length; i++) {
            datas[i] = gamesMortgage[contracts[i]][tokenIds[i]];
        }
        return datas;
    }
    function queryTrainMortgageBatch(address[] memory contracts, uint256[] memory tokenIds) external view returns (LibMortgage.mortgageDataStruct[] memory) {
        require(contracts.length == tokenIds.length, 'ELFMORT: length error');
        LibMortgage.mortgageDataStruct[] memory datas = new LibMortgage.mortgageDataStruct[](tokenIds.length);
        for (uint i = 0; i < contracts.length; i++) {
            datas[i] = trainMortgage[contracts[i]][tokenIds[i]];
        }
        return datas;
    }

    function _mortgageCheck(LibMortgage.mortgageDataStruct memory datas) internal view returns (LibMortgage.mortgageStatus) {
        if (datas.quantity == 0 && datas.startTime == 0) {
            return LibMortgage.mortgageStatus.NONE;
        } else {
            if (block.timestamp.sub(datas.startTime) >= 1 days) {
                return LibMortgage.mortgageStatus.EXPIRE;
            } else {
                return LibMortgage.mortgageStatus.NORMAL;
            }
        }
    }

    function gameMortgageStart(address contractAddress, uint256 tokenId) external {
        address sender = _msgSender();
        if (ownerMap[contractAddress][tokenId] != sender) {
            require(IERC721Upgradeable(contractAddress).ownerOf(tokenId) == _msgSender(), 'ELFMORT: not owned');
            IERC721Upgradeable(contractAddress).transferFrom(_msgSender(), address(this), tokenId);
            ownerMap[contractAddress][tokenId] = sender;
            emit NFTMortgageStart(contractAddress, tokenId, _msgSender());
        }
        require(gamesMortgage[contractAddress][tokenId].startTime == 0, 'ELFMORT: in mortgage');
        if (gamesMortgageELFTAmt > 0) {
            address elftContract = addressManager.getAddress('elfToken');
            IERC20Upgradeable(elftContract).transferFrom(sender, address(this), gamesMortgageELFTAmt);
            gamesMortgage[contractAddress][tokenId].quantity = gamesMortgageELFTAmt;
        }
        gamesMortgage[contractAddress][tokenId].startTime = block.timestamp;
        emit GamesMortgageStart(contractAddress, tokenId, _msgSender());
    }
    function gameMortgageCancel(address contractAddress, uint256 tokenId) public {
        require(ownerMap[contractAddress][tokenId] == _msgSender(), 'ELFMORT: not owned');
        LibMortgage.mortgageStatus status = gamesMortgageCheck(contractAddress, tokenId);
        if (status == LibMortgage.mortgageStatus.NONE) {
            revert('ELFMORT: not mortgage');
        } else if (status == LibMortgage.mortgageStatus.NORMAL) {
            revert('ELFMORT: in mortgage');
        }
        _releaseToken(contractAddress, tokenId, _msgSender(), 2);
        emit GamesMortgageCancel(contractAddress, tokenId, _msgSender());
    }

    function mortgageReleaseAll(address contractAddress, uint256 tokenId) external {
        if (trainMortgage[contractAddress][tokenId].startTime != 0) {
            trainMortgageCancel(contractAddress, tokenId);
        }
        if (gamesMortgage[contractAddress][tokenId].startTime != 0) {
            gameMortgageCancel(contractAddress, tokenId);
        }
    }
    /// @dev params releaseType: 1 train ELFT 2 game ELFT 3 NFT
    function _releaseToken(address contractAddr, uint256 tokenId, address to, uint8 releaseType) internal {
        require(ownerMap[contractAddr][tokenId] == to, 'ELFMORT: not owner');
        address tokenContractAddress = addressManager.getAddress('elfToken');
        uint256 quantityTrain = trainMortgage[contractAddr][tokenId].quantity;
        uint256 quantityGames = gamesMortgage[contractAddr][tokenId].quantity;
        // train elft release
        uint256 elfTokenAmount = 0;
        if (releaseType == 1) {
            elfTokenAmount = elfTokenAmount.add(quantityTrain);
            trainMortgage[contractAddr][tokenId].startTime = 0;
            trainMortgage[contractAddr][tokenId].quantity = 0;
        }
        // game elft release
        if (releaseType == 2) {
            elfTokenAmount = elfTokenAmount.add(quantityGames);
            gamesMortgage[contractAddr][tokenId].startTime = 0;
            gamesMortgage[contractAddr][tokenId].quantity = 0;
        }
        // release elftoken
        if (elfTokenAmount > 0) {
            IERC20Upgradeable(tokenContractAddress).transfer(to, elfTokenAmount);
        }
        bool isReleaseAll = gamesMortgage[contractAddr][tokenId].startTime == 0 && trainMortgage[contractAddr][tokenId].startTime == 0;
        // release nft
        if (releaseType == 3 || isReleaseAll) {
            ownerMap[contractAddr][tokenId] = address(0);
            IERC721Upgradeable(contractAddr).safeTransferFrom(address(this), to, tokenId);
            emit NFTMortgageCancel(contractAddr, tokenId, to);
        }
    }

    function setTrainMortgageQuantity(uint256 _quantity) external onlyOwner {
        trainMortgageQuantity = _quantity;
    }

    function setGamesMortgageQuantity(uint256 _gamesMortgageELFTAmt) external onlyOwner {
        gamesMortgageELFTAmt = _gamesMortgageELFTAmt;
    }

    function setAddressManager(IAddressManager _addressManager) external onlyOwner {
        addressManager = _addressManager;
    }
}