// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

library PresaleTypes {
    struct EditionData {
        string name;
        string symbol;
        string description;
        string animationUrl;
        bytes32 animationHash;
        string imageUrl;
        bytes32 imageHash;
        uint256 editionSize;
        uint256 royaltyBPS;
        address owner;
    }

    struct SaleData {
        uint256 presaleStartTime;
        uint256 publicStartTime;
        uint256 presalePrice;
        uint256 standardPrice;
        uint256 maxMintsPerPresale;
        uint256 maxMintsPerPublicSale;
        address fundsRecipent;
        bytes32 merkleRoot;
    }
}
