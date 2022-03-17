// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol';
// lib
import './lib/LibWhiteList.sol';

contract WhiteList is Initializable {
    using SafeMathUpgradeable for uint;
    uint256 public constant MaximumPurchaseQuantity = 10;
    uint256 public constant bnbElfBallSupply = 4000;
    uint256 public constant tokenElfBallSupply = 4000;
    uint256 public bnbBallStartBlock;
    uint256 public tokenBallStartBlock;
    uint256 public BnbWhiteListQuantity;
    uint256 public TokenWhiteListQuantity;
    mapping(address => uint256) public purchasedQuantity;
    mapping(address => uint256) public purchasedQuantityToken;

    // isBuy
    mapping(address => bool) public isWhitelist;
    mapping(address => bool) public isWhitelistToken;
    // box conf
    LibWhiteList.BlindConf public blindConf;
    LibWhiteList.BlindConf public blindConfToken;

    event InitTokenBallStartBlock(uint256 startBlock);


    // init
    function _WHITELIST_INIT (
        uint256 bnbBallPrice,
        uint256 tokenBallPrice,
        address[] memory bnbWhiteListAddress,
        uint256 _startBlock
    ) internal  initializer{
        bnbBallStartBlock = _startBlock;
        blindConf.price = bnbBallPrice;
        blindConfToken.price = tokenBallPrice;
        _addWhiteListAmountBatch(bnbWhiteListAddress);
    }

    function _setTokenBallPrice(uint256 price) internal {
        blindConfToken.price = price;
    }

    function _initTokenBallStartBLock(uint256 startBLock) internal {
        require(tokenBallStartBlock == 0, 'ElfBallNFT: Repeat settings');
        tokenBallStartBlock = startBLock;
        emit InitTokenBallStartBlock(tokenBallStartBlock);
    }
    // add
    function _addWhiteListAmountBatch(address[] memory account) internal {
        BnbWhiteListQuantity = BnbWhiteListQuantity.add(account.length);
        for (uint8 i = 0; i < account.length; i++) {
           isWhitelist[account[i]] = true;
        }
    }

    function _addTokenWhiteListAmount(address[] memory account) internal {
        TokenWhiteListQuantity = TokenWhiteListQuantity.add(account.length);
        for (uint8 i = 0; i < account.length; i++) {
            isWhitelistToken[account[i]] = true;
        }
    }

    function getAllowBuyAmount(address account) public view returns (uint256) {
        uint256 amount;
        if (bnbBallStartBlock == 0) {
            return 0;
        }
        if (block.number >= bnbBallStartBlock) {
            amount = MaximumPurchaseQuantity.sub(purchasedQuantity[account]);
            if (block.number.sub(bnbBallStartBlock) <= 1200 && !isWhitelist[account] && BnbWhiteListQuantity > 0) {
                amount = 0;
            }
        }
        uint256 rSupply = bnbElfBallSupply.sub(blindConf.used);
        if (amount > rSupply) {
            amount = rSupply;
        }
        return amount;
    }

     function getAllowBuyAmountToken(address account) public view returns (uint256) {
        uint256 amount;
        if (tokenBallStartBlock == 0) {
            return 0;
        }
        if (block.number >= tokenBallStartBlock) {
            amount = MaximumPurchaseQuantity.sub(purchasedQuantityToken[account]);
            if (block.number.sub(tokenBallStartBlock) <= 1200 && !isWhitelistToken[account] && TokenWhiteListQuantity > 0) {
                amount = 0;
            }
        }
        uint256 rSupply = tokenElfBallSupply.sub(blindConfToken.used);
        if (amount > rSupply) {
            amount = rSupply;
        }
        return amount;
    }

    function _addUsed(address account, uint256 amount) internal {
        purchasedQuantity[account] = purchasedQuantity[account].add(amount);
        blindConf.used = blindConf.used.add(amount);
    }

     function _addUsedToken(address account, uint256 amount) internal {
        purchasedQuantityToken[account] = purchasedQuantityToken[account].add(amount);
        blindConfToken.used = blindConfToken.used.add(amount);
    }
}