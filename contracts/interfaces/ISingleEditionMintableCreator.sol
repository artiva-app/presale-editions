// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {ISingleEditionMintable} from "./ISingleEditionMintable.sol";

interface ISingleEditionMintableCreator {
    function createEdition(
        string memory _name,
        string memory _symbol,
        string memory _description,
        string memory _animationUrl,
        bytes32 _animationHash,
        string memory _imageUrl,
        bytes32 _imageHash,
        uint256 _editionSize,
        uint256 _royaltyBPS,
        uint256 _salePrice
    ) external returns (uint256);

    function getEditionAtId(uint256 editionId) external
        view
        returns (ISingleEditionMintable);
}