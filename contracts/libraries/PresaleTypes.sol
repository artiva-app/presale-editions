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

    struct Presale {
        bool active;
        uint256 presalePrice;
        uint256 presaleAmount;
        address fundsRecipent;
        uint256 standardPrice;
        bytes32 merkleRoot;
    }
}
