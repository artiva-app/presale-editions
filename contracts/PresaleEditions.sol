// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import {IPresaleEditions} from "./interfaces/IPresaleEditions.sol";
import {ISingleEditionMintableCreator} from "./interfaces/ISingleEditionMintableCreator.sol";
import {ISingleEditionMintable} from "./interfaces/ISingleEditionMintable.sol";
import {PresaleTypes} from "./libraries/PresaleTypes.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract PresaleEditions is IPresaleEditions {
    event CreatedPresale(address editionContractAddress, uint256 editionId, PresaleTypes.Presale presale);
    event PresaleUpdated(uint256 editionId, PresaleTypes.Presale presale);
    event EditionSold(uint256 editionId, uint256 amount, address buyer, PresaleTypes.Presale presale);
    event FundsWithdrawn(uint256 editionId, uint256 amount);

    address public singleEditionMintableCreatorAddress;

    mapping(uint256 => PresaleTypes.Presale) public editionIdToPresale;
    mapping(uint256 => uint256) public editionIdToBalance;
    //EditionId => Claimant Address => Is Claimed
    mapping(uint256 => mapping(address => bool)) claimed;

    modifier OnlyEditionOwner(uint256 _editionId) {
        ISingleEditionMintable edition = ISingleEditionMintableCreator(singleEditionMintableCreatorAddress).getEditionAtId(_editionId);
        require(msg.sender == edition.owner(), "NOT_OWNER");
        _;
    }

    constructor(address _singleEditionMintableCreatorAddress) {
        singleEditionMintableCreatorAddress = _singleEditionMintableCreatorAddress;
    }

    function createPresaleEdition(PresaleTypes.EditionData memory _editionData, PresaleTypes.Presale memory _presaleData) external returns (uint256) {
        ISingleEditionMintableCreator creator = ISingleEditionMintableCreator(singleEditionMintableCreatorAddress);
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

        editionIdToPresale[editionId] = _presaleData;

        emit CreatedPresale(address(edition), editionId, _presaleData);
        return (editionId);
    }

    function purchase(uint256 _editionId, uint256 _amount) external payable {
        PresaleTypes.Presale storage presale = editionIdToPresale[_editionId];
        require(!presale.active, "PRESALE_ACTIVE");
        require(msg.value == presale.standardPrice * _amount, "INVALID_PRICE");
        editionIdToBalance[_editionId] += presale.standardPrice * _amount;
        _mint(_editionId, _amount);
    }

    function purchasePresale(
        uint256 _editionId,
        uint256 _amount,
        bytes32[] calldata _merkleProof
    ) external payable {
        PresaleTypes.Presale storage presale = editionIdToPresale[_editionId];
        require(presale.active, "NOT_ACTIVE");
        require(!claimed[_editionId][msg.sender], "ALREADY_CLAIMED");
        require(_amount <= presale.presaleAmount, "INVALID_AMOUNT");
        require(msg.value == presale.presalePrice * _amount, "INVALID_PRICE");

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(_merkleProof, presale.merkleRoot, leaf), "PROOF_NOT_VERIFIED");

        claimed[_editionId][msg.sender] = true;
        editionIdToBalance[_editionId] += presale.presalePrice * _amount;
        _mint(_editionId, _amount);
    }

    function setPresalePrice(uint256 _editionId, uint256 _presalePrice) external OnlyEditionOwner(_editionId) {
        editionIdToPresale[_editionId].presalePrice = _presalePrice;
        emit PresaleUpdated(_editionId, editionIdToPresale[_editionId]);
    }

    function setStandardPrice(uint256 _editionId, uint256 _standardPrice) external OnlyEditionOwner(_editionId) {
        editionIdToPresale[_editionId].standardPrice = _standardPrice;
        emit PresaleUpdated(_editionId, editionIdToPresale[_editionId]);
    }

    function setPresaleActive(uint256 _editionId, bool _active) external OnlyEditionOwner(_editionId) {
        editionIdToPresale[_editionId].active = _active;
        emit PresaleUpdated(_editionId, editionIdToPresale[_editionId]);
    }

    function setMerkleRoot(uint256 _editionId, bytes32 _merkleRoot) external OnlyEditionOwner(_editionId) {
        editionIdToPresale[_editionId].merkleRoot = _merkleRoot;
        emit PresaleUpdated(_editionId, editionIdToPresale[_editionId]);
    }

    function withdraw(uint256 _editionId) external {
        PresaleTypes.Presale storage presale = editionIdToPresale[_editionId];
        ISingleEditionMintable edition = ISingleEditionMintableCreator(singleEditionMintableCreatorAddress).getEditionAtId(_editionId);
        uint256 balance = editionIdToBalance[_editionId];
        editionIdToBalance[_editionId] = 0;
        Address.sendValue(payable(presale.fundsRecipent), balance);
        emit FundsWithdrawn(_editionId, balance);
    }

    function _mint(uint256 _editionId, uint256 _amount) internal {
        ISingleEditionMintable edition = ISingleEditionMintableCreator(singleEditionMintableCreatorAddress).getEditionAtId(_editionId);
        for (uint256 i = 0; i < _amount; i++) {
            edition.mintEdition(msg.sender);
        }
        emit EditionSold(_editionId, _amount, msg.sender, editionIdToPresale[_editionId]);
    }
}
