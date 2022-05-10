// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import {PresaleTypes} from "../libraries/PresaleTypes.sol";

interface IPresaleEditions {
    function createPresaleEdition(PresaleTypes.EditionData memory _editionData, PresaleTypes.SaleData memory _saleData) external returns (uint256);

    function presale(
        uint256 _editionId,
        uint256 _amount,
        bytes32[] calldata _merkleProof
    ) external payable;
}
