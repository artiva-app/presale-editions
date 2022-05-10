// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import {IPresaleEditions} from "./interfaces/IPresaleEditions.sol";
import {ISingleEditionMintableCreator} from "./interfaces/ISingleEditionMintableCreator.sol";
import {ISingleEditionMintable} from "./interfaces/ISingleEditionMintable.sol";
import {PresaleTypes} from "./libraries/PresaleTypes.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract PresaleEditions is IPresaleEditions {
    event CreatedEdition(address editionContractAddress, uint256 editionId, PresaleTypes.SaleData saleData);
    event SaleDataUpdated(uint256 editionId, PresaleTypes.SaleData saleData);
    event EditionSold(uint256 editionId, uint256 amount, address buyer, PresaleTypes.SaleData saleData);
    event FundsWithdrawn(uint256 editionId, uint256 amount);

    address public singleEditionMintableCreatorAddress;

    mapping(uint256 => PresaleTypes.SaleData) public editionIdToSaleData;
    mapping(uint256 => uint256) public editionIdToBalance;
    //EditionId => Claimant Address => Amount Claimed
    mapping(uint256 => mapping(address => uint256)) presalesClaimed;
    mapping(uint256 => mapping(address => uint256)) publicSalesClaimed;

    modifier OnlyEditionOwner(uint256 _editionId) {
        ISingleEditionMintable edition = ISingleEditionMintableCreator(singleEditionMintableCreatorAddress).getEditionAtId(_editionId);
        require(msg.sender == edition.owner(), "NOT_OWNER");
        _;
    }

    constructor(address _singleEditionMintableCreatorAddress) {
        singleEditionMintableCreatorAddress = _singleEditionMintableCreatorAddress;
    }

    function createPresaleEdition(PresaleTypes.EditionData memory _editionData, PresaleTypes.SaleData memory _saleData) external returns (uint256) {
        ISingleEditionMintableCreator creator = ISingleEditionMintableCreator(singleEditionMintableCreatorAddress);

        require(_saleData.presaleStartTime < _saleData.publicStartTime, "PRESALE_NOT_BEFORE_PUBLIC");
        require(_saleData.presaleStartTime > block.timestamp, "PRESALE_NOT_IN_FUTURE");

        uint256 editionId = creator.createEdition(
            _editionData.name,
            _editionData.symbol,
            _editionData.description,
            _editionData.animationUrl,
            _editionData.animationHash,
            _editionData.imageUrl,
            _editionData.imageHash,
            _editionData.editionSize,
            _editionData.royaltyBPS,
            0
        );

        ISingleEditionMintable edition = creator.getEditionAtId(editionId);
        edition.setApprovedMinter(address(this), true);
        edition.transferOwnership(_editionData.owner);

        editionIdToSaleData[editionId] = _saleData;

        emit CreatedEdition(address(edition), editionId, _saleData);
        return (editionId);
    }

    function presale(
        uint256 _editionId,
        uint256 _amount,
        bytes32[] calldata _merkleProof
    ) external payable {
        PresaleTypes.SaleData storage saleData = editionIdToSaleData[_editionId];
        require(presaleActive(_editionId), "PRESALE_NOT_ACTIVE");
        require(presalesClaimed[_editionId][msg.sender] + _amount <= saleData.maxMintsPerPresale, "PRESALE_CLAIMS_MAXED");
        require(msg.value == saleData.presalePrice * _amount, "INVALID_PRICE");

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(_merkleProof, saleData.merkleRoot, leaf), "PROOF_NOT_VERIFIED");

        presalesClaimed[_editionId][msg.sender] += _amount;
        editionIdToBalance[_editionId] += saleData.presalePrice * _amount;
        _mint(_editionId, _amount);
    }

    function publicSale(uint256 _editionId, uint256 _amount) external payable {
        PresaleTypes.SaleData storage saleData = editionIdToSaleData[_editionId];
        require(publicSaleActive(_editionId), "SALE_NOT_ACTIVE");
        require(msg.value == saleData.standardPrice * _amount, "INVALID_PRICE");
        editionIdToBalance[_editionId] += saleData.standardPrice * _amount;
        _mint(_editionId, _amount);
    }

    function setSaleData(uint256 _editionId, PresaleTypes.SaleData memory _saleData) external OnlyEditionOwner(_editionId) {
        editionIdToSaleData[_editionId] = _saleData;
        emit SaleDataUpdated(_editionId, editionIdToSaleData[_editionId]);
    }

    function withdraw(uint256 _editionId) external {
        PresaleTypes.SaleData storage saleData = editionIdToSaleData[_editionId];
        uint256 balance = editionIdToBalance[_editionId];
        editionIdToBalance[_editionId] = 0;
        Address.sendValue(payable(saleData.fundsRecipent), balance);
        emit FundsWithdrawn(_editionId, balance);
    }

    function _mint(uint256 _editionId, uint256 _amount) internal {
        ISingleEditionMintable edition = ISingleEditionMintableCreator(singleEditionMintableCreatorAddress).getEditionAtId(_editionId);
        for (uint256 i = 0; i < _amount; i++) {
            edition.mintEdition(msg.sender);
        }
        emit EditionSold(_editionId, _amount, msg.sender, editionIdToSaleData[_editionId]);
    }

    function presaleActive(uint256 _editionId) public view returns (bool) {
        return block.timestamp >= editionIdToSaleData[_editionId].presaleStartTime;
    }

    function publicSaleActive(uint256 _editionId) public view returns (bool) {
        return block.timestamp >= editionIdToSaleData[_editionId].presaleStartTime;
    }
}
