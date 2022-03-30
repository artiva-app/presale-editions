// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import {PresaleTypes} from "../libraries/PresaleTypes.sol";

interface IPresaleEditions {
    function createPresaleEdition(PresaleTypes.EditionData memory _editionData, PresaleTypes.Presale memory _presaleData) external returns (uint256);

    function purchasePresale(
        uint256 _editionId,
        uint256 _amount,
        bytes32[] calldata _merkleProof
    ) external payable;
}
