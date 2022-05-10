// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import {VM} from "./utils/VM.sol";
import {SingleEditionMintable} from "./utils/SingleEditionMintable.sol";
import {SingleEditionMintableCreator} from "./utils/SingleEditionMintableCreator.sol";
import {SharedNFTLogic} from "./utils/SharedNFTLogic.sol";
import {PresaleEditions} from "../PresaleEditions.sol";
import {IPresaleEditions} from "../interfaces/IPresaleEditions.sol";
import {PresaleTypes} from "../libraries/PresaleTypes.sol";

contract PresaleEditionsTest is DSTest {
    VM internal vm;

    SharedNFTLogic internal nftLogic;
    SingleEditionMintable internal singleEditionTemplate;
    SingleEditionMintableCreator internal singleEditionCreator;
    PresaleEditions internal presaleEditions;

    address internal creator;
    address internal otherCreator;
    address internal presaleBuyer;
    address internal standardBuyer;

    bytes32 internal defaultMerkleRoot = 0x83bef000c8e3c4054eda44e44c2f94736f97130b331c7f5a58346c415ae9dd04;

    function setUp() public {
        // Cheatcodes
        vm = VM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

        nftLogic = new SharedNFTLogic();
        singleEditionTemplate = new SingleEditionMintable(nftLogic);
        singleEditionCreator = new SingleEditionMintableCreator(address(singleEditionTemplate));
        presaleEditions = new PresaleEditions(address(singleEditionCreator));

        creator = address(1);
        otherCreator = address(2);
        presaleBuyer = address(0xa471C9508Acf13867282f36cfCe5c41D719ab78B);
        standardBuyer = address(0x7D2Ce20c29395E3a7faBA21499Ea50F4045EdB3d);

        vm.deal(address(creator), 100 ether);
        vm.deal(address(otherCreator), 100 ether);
        vm.deal(address(presaleBuyer), 100 ether);
        vm.deal(address(standardBuyer), 100 ether);
    }

    /// ------------ CREATE EDITION ------------ ///

    function testGas_CreateEdition() public {
        PresaleTypes.EditionData memory editionData = PresaleTypes.EditionData("Test", "TEST", "", "", 0, "", 0, 10, 10, creator);
        PresaleTypes.SaleData memory saleData = PresaleTypes.SaleData(
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            0.5 ether,
            1 ether,
            3,
            6,
            creator,
            defaultMerkleRoot
        );

        vm.prank(creator);
        presaleEditions.createPresaleEdition(editionData, saleData);
    }

    function testCreateEdition() public {
        PresaleTypes.EditionData memory editionData = PresaleTypes.EditionData("Test", "TEST", "", "", 0, "", 0, 5, 10, creator);
        PresaleTypes.SaleData memory saleData = PresaleTypes.SaleData(
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            0.5 ether,
            1 ether,
            3,
            6,
            creator,
            defaultMerkleRoot
        );

        vm.prank(creator);
        uint256 editionId = presaleEditions.createPresaleEdition(editionData, saleData);

        SingleEditionMintable edition = singleEditionCreator.getEditionAtId(editionId);
        require(edition.owner() == creator);
        require(edition.editionSize() == 5);
        require(edition.salePrice() == 0);

        (
            uint256 presaleStartTime,
            uint256 publicStartTime,
            uint256 presalePrice,
            uint256 standardPrice,
            uint256 maxMintsPerPresale,
            uint256 maxMintsPerPublicSale,
            address fundsRecipent,
            bytes32 merkleRoot
        ) = presaleEditions.editionIdToSaleData(editionId);
        require(presaleStartTime == block.timestamp + 1 days);
        require(publicStartTime == block.timestamp + 2 days);
        require(presalePrice == 0.5 ether);
        require(standardPrice == 1 ether);
        require(maxMintsPerPresale == 3);
        require(maxMintsPerPublicSale == 6);
        require(fundsRecipent == creator);
        require(merkleRoot == defaultMerkleRoot);
    }

    function testRevert_PresaleNotBeforePublic() public {
        PresaleTypes.EditionData memory editionData = PresaleTypes.EditionData("Test", "TEST", "", "", 0, "", 0, 10, 10, creator);
        PresaleTypes.SaleData memory saleData = PresaleTypes.SaleData(
            block.timestamp + 2 days,
            block.timestamp + 1 days,
            0.5 ether,
            1 ether,
            3,
            6,
            creator,
            defaultMerkleRoot
        );

        vm.prank(creator);
        vm.expectRevert("PRESALE_NOT_BEFORE_PUBLIC");
        presaleEditions.createPresaleEdition(editionData, saleData);
    }

    function testRevert_PresaleNotInFuture() public {
        PresaleTypes.EditionData memory editionData = PresaleTypes.EditionData("Test", "TEST", "", "", 0, "", 0, 10, 10, creator);
        PresaleTypes.SaleData memory saleData = PresaleTypes.SaleData(
            block.timestamp,
            block.timestamp + 1 days,
            0.5 ether,
            1 ether,
            3,
            6,
            creator,
            defaultMerkleRoot
        );

        vm.prank(creator);
        vm.expectRevert("PRESALE_NOT_IN_FUTURE");
        presaleEditions.createPresaleEdition(editionData, saleData);
    }

    /// ------------ PURCHAE PRESALE EDITION ------------ ///

    function testPurchasePresaleEdition() public {
        PresaleTypes.EditionData memory editionData = PresaleTypes.EditionData("Test", "TEST", "", "", 0, "", 0, 5, 10, creator);
        PresaleTypes.SaleData memory saleData = PresaleTypes.SaleData(
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            0.5 ether,
            1 ether,
            3,
            6,
            creator,
            defaultMerkleRoot
        );

        vm.prank(creator);
        uint256 editionId = presaleEditions.createPresaleEdition(editionData, saleData);
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = bytes32(0x12e46814651febb3096e11596a99293a2279d73edd9935d9528163bc1360baa9);
        proof[1] = bytes32(0x29ec45f0409d89a93bb3d009b77ef1c24da4b04d81e7f149ff41fac10df8a942);

        vm.warp(1 days);
        vm.prank(presaleBuyer);
        presaleEditions.presale{value: 0.5 ether}(editionId, 1, proof);
        require(presaleEditions.editionIdToBalance(editionId) == 0.5 ether);
    }

    function testBatchPurchasePresaleEdition() public {
        PresaleTypes.EditionData memory editionData = PresaleTypes.EditionData("Test", "TEST", "", "", 0, "", 0, 5, 10, creator);
        PresaleTypes.SaleData memory saleData = PresaleTypes.SaleData(
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            0.5 ether,
            1 ether,
            3,
            6,
            creator,
            defaultMerkleRoot
        );

        vm.prank(creator);
        uint256 editionId = presaleEditions.createPresaleEdition(editionData, saleData);
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = bytes32(0x12e46814651febb3096e11596a99293a2279d73edd9935d9528163bc1360baa9);
        proof[1] = bytes32(0x29ec45f0409d89a93bb3d009b77ef1c24da4b04d81e7f149ff41fac10df8a942);

        vm.warp(1 days);
        vm.prank(presaleBuyer);
        presaleEditions.presale{value: 1 ether}(editionId, 2, proof);
        require(presaleEditions.editionIdToBalance(editionId) == 1 ether);
    }

    function testRevert_PresaleInvalidProof() public {
        PresaleTypes.EditionData memory editionData = PresaleTypes.EditionData("Test", "TEST", "", "", 0, "", 0, 5, 10, creator);
        PresaleTypes.SaleData memory saleData = PresaleTypes.SaleData(
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            0.5 ether,
            1 ether,
            3,
            6,
            creator,
            defaultMerkleRoot
        );

        vm.prank(creator);
        uint256 editionId = presaleEditions.createPresaleEdition(editionData, saleData);
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = bytes32(0x12e46814651febb3096e11596a99293a2279d73edd9935d9528163bc1360baa8);
        proof[1] = bytes32(0x29ec45f0409d89a93bb3d009b77ef1c24da4b04d81e7f149ff41fac10df8a942);

        vm.warp(1 days);
        vm.prank(presaleBuyer);
        vm.expectRevert("PROOF_NOT_VERIFIED");
        presaleEditions.presale{value: 0.5 ether}(editionId, 1, proof);
    }

    function testRevert_PresaleInvalidAddress() public {
        PresaleTypes.EditionData memory editionData = PresaleTypes.EditionData("Test", "TEST", "", "", 0, "", 0, 5, 10, creator);
        PresaleTypes.SaleData memory saleData = PresaleTypes.SaleData(
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            0.5 ether,
            1 ether,
            3,
            6,
            creator,
            defaultMerkleRoot
        );

        vm.prank(creator);
        uint256 editionId = presaleEditions.createPresaleEdition(editionData, saleData);
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = bytes32(0x12e46814651febb3096e11596a99293a2279d73edd9935d9528163bc1360baa9);
        proof[1] = bytes32(0x29ec45f0409d89a93bb3d009b77ef1c24da4b04d81e7f149ff41fac10df8a942);

        vm.warp(1 days);
        vm.prank(standardBuyer);
        vm.expectRevert("PROOF_NOT_VERIFIED");
        presaleEditions.presale{value: 0.5 ether}(editionId, 1, proof);
    }

    function testRevert_PresaleAlreadyClaimed() public {
        PresaleTypes.EditionData memory editionData = PresaleTypes.EditionData("Test", "TEST", "", "", 0, "", 0, 5, 10, creator);
        PresaleTypes.SaleData memory saleData = PresaleTypes.SaleData(
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            0.5 ether,
            1 ether,
            3,
            6,
            creator,
            defaultMerkleRoot
        );

        vm.prank(creator);
        uint256 editionId = presaleEditions.createPresaleEdition(editionData, saleData);
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = bytes32(0x12e46814651febb3096e11596a99293a2279d73edd9935d9528163bc1360baa9);
        proof[1] = bytes32(0x29ec45f0409d89a93bb3d009b77ef1c24da4b04d81e7f149ff41fac10df8a942);

        vm.warp(1 days);
        vm.startPrank(presaleBuyer);
        presaleEditions.presale{value: 1.5 ether}(editionId, 3, proof);

        vm.warp(1 days);
        vm.expectRevert("PRESALE_CLAIMS_MAXED");
        presaleEditions.presale{value: 0.5 ether}(editionId, 1, proof);
        vm.stopPrank();
    }

    function testRevert_PresaleInvalidPrice() public {
        PresaleTypes.EditionData memory editionData = PresaleTypes.EditionData("Test", "TEST", "", "", 0, "", 0, 5, 10, creator);
        PresaleTypes.SaleData memory saleData = PresaleTypes.SaleData(
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            0.5 ether,
            1 ether,
            3,
            6,
            creator,
            defaultMerkleRoot
        );

        vm.prank(creator);
        uint256 editionId = presaleEditions.createPresaleEdition(editionData, saleData);
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = bytes32(0x12e46814651febb3096e11596a99293a2279d73edd9935d9528163bc1360baa9);
        proof[1] = bytes32(0x29ec45f0409d89a93bb3d009b77ef1c24da4b04d81e7f149ff41fac10df8a942);

        vm.warp(1 days);
        vm.prank(presaleBuyer);
        vm.expectRevert("INVALID_PRICE");
        presaleEditions.presale{value: 0.6 ether}(editionId, 1, proof);
    }

    function testRevert_PresaleNotActive() public {
        PresaleTypes.EditionData memory editionData = PresaleTypes.EditionData("Test", "TEST", "", "", 0, "", 0, 5, 10, creator);
        PresaleTypes.SaleData memory saleData = PresaleTypes.SaleData(
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            0.5 ether,
            1 ether,
            3,
            6,
            creator,
            defaultMerkleRoot
        );

        vm.prank(creator);
        uint256 editionId = presaleEditions.createPresaleEdition(editionData, saleData);
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = bytes32(0x12e46814651febb3096e11596a99293a2279d73edd9935d9528163bc1360baa9);
        proof[1] = bytes32(0x29ec45f0409d89a93bb3d009b77ef1c24da4b04d81e7f149ff41fac10df8a942);

        vm.prank(presaleBuyer);
        vm.expectRevert("PRESALE_NOT_ACTIVE");
        presaleEditions.presale{value: 0.5 ether}(editionId, 1, proof);
    }

    function testRevert_PresaleInvalidAmount() public {
        PresaleTypes.EditionData memory editionData = PresaleTypes.EditionData("Test", "TEST", "", "", 0, "", 0, 5, 10, creator);
        PresaleTypes.SaleData memory saleData = PresaleTypes.SaleData(
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            0.5 ether,
            1 ether,
            3,
            6,
            creator,
            defaultMerkleRoot
        );

        vm.prank(creator);
        uint256 editionId = presaleEditions.createPresaleEdition(editionData, saleData);
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = bytes32(0x12e46814651febb3096e11596a99293a2279d73edd9935d9528163bc1360baa9);
        proof[1] = bytes32(0x29ec45f0409d89a93bb3d009b77ef1c24da4b04d81e7f149ff41fac10df8a942);

        vm.warp(1 days);
        vm.prank(presaleBuyer);
        vm.expectRevert("PRESALE_CLAIMS_MAXED");
        presaleEditions.presale{value: 0.5 ether}(editionId, 6, proof);
    }

    function testRevert_PresaleInvalidBatchPrice() public {
        PresaleTypes.EditionData memory editionData = PresaleTypes.EditionData("Test", "TEST", "", "", 0, "", 0, 5, 10, creator);
        PresaleTypes.SaleData memory saleData = PresaleTypes.SaleData(
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            0.5 ether,
            1 ether,
            3,
            6,
            creator,
            defaultMerkleRoot
        );

        vm.prank(creator);
        uint256 editionId = presaleEditions.createPresaleEdition(editionData, saleData);
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = bytes32(0x12e46814651febb3096e11596a99293a2279d73edd9935d9528163bc1360baa9);
        proof[1] = bytes32(0x29ec45f0409d89a93bb3d009b77ef1c24da4b04d81e7f149ff41fac10df8a942);

        vm.warp(1 days);
        vm.prank(presaleBuyer);
        vm.expectRevert("INVALID_PRICE");
        presaleEditions.presale{value: 0.5 ether}(editionId, 2, proof);
    }

    /// ------------ PURCHAE STANDARD EDITION ------------ ///

    function testPurchaseStandardEdition() public {
        PresaleTypes.EditionData memory editionData = PresaleTypes.EditionData("Test", "TEST", "", "", 0, "", 0, 5, 10, creator);
        PresaleTypes.SaleData memory saleData = PresaleTypes.SaleData(
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            0.5 ether,
            1 ether,
            3,
            6,
            creator,
            defaultMerkleRoot
        );

        vm.prank(creator);
        uint256 editionId = presaleEditions.createPresaleEdition(editionData, saleData);

        vm.warp(2 days);
        vm.prank(standardBuyer);
        presaleEditions.publicSale{value: 1 ether}(editionId, 1);
        require(presaleEditions.editionIdToBalance(editionId) == 1 ether);
    }

    function testBatchPurchaseStandardEdition() public {
        PresaleTypes.EditionData memory editionData = PresaleTypes.EditionData("Test", "TEST", "", "", 0, "", 0, 5, 10, creator);
        PresaleTypes.SaleData memory saleData = PresaleTypes.SaleData(
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            0.5 ether,
            1 ether,
            3,
            6,
            creator,
            defaultMerkleRoot
        );

        vm.prank(creator);
        uint256 editionId = presaleEditions.createPresaleEdition(editionData, saleData);
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = bytes32(0x12e46814651febb3096e11596a99293a2279d73edd9935d9528163bc1360baa9);
        proof[1] = bytes32(0x29ec45f0409d89a93bb3d009b77ef1c24da4b04d81e7f149ff41fac10df8a942);

        vm.warp(2 days);
        vm.prank(standardBuyer);
        presaleEditions.publicSale{value: 2 ether}(editionId, 2);
        require(presaleEditions.editionIdToBalance(editionId) == 2 ether);
    }

    function testRevert_StandardInvalidPrice() public {
        PresaleTypes.EditionData memory editionData = PresaleTypes.EditionData("Test", "TEST", "", "", 0, "", 0, 5, 10, creator);
        PresaleTypes.SaleData memory saleData = PresaleTypes.SaleData(
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            0.5 ether,
            1 ether,
            3,
            6,
            creator,
            defaultMerkleRoot
        );

        vm.prank(creator);
        uint256 editionId = presaleEditions.createPresaleEdition(editionData, saleData);

        vm.warp(2 days);
        vm.prank(standardBuyer);
        vm.expectRevert("INVALID_PRICE");
        presaleEditions.publicSale{value: 0.6 ether}(editionId, 1);
    }

    function testRevert_SaleClaimsMaxed() public {
        PresaleTypes.EditionData memory editionData = PresaleTypes.EditionData("Test", "TEST", "", "", 0, "", 0, 5, 10, creator);
        PresaleTypes.SaleData memory saleData = PresaleTypes.SaleData(
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            0.5 ether,
            1 ether,
            3,
            6,
            creator,
            defaultMerkleRoot
        );

        vm.prank(creator);
        uint256 editionId = presaleEditions.createPresaleEdition(editionData, saleData);

        vm.warp(2 days);
        vm.prank(standardBuyer);
        vm.expectRevert("SALE_CLAIMS_MAXED");
        presaleEditions.publicSale{value: 7 ether}(editionId, 7);
    }

    function testRevert_StandardSaleNotActive() public {
        PresaleTypes.EditionData memory editionData = PresaleTypes.EditionData("Test", "TEST", "", "", 0, "", 0, 5, 10, creator);
        PresaleTypes.SaleData memory saleData = PresaleTypes.SaleData(
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            0.5 ether,
            1 ether,
            3,
            6,
            creator,
            defaultMerkleRoot
        );

        vm.prank(creator);
        uint256 editionId = presaleEditions.createPresaleEdition(editionData, saleData);

        vm.prank(standardBuyer);
        vm.expectRevert("SALE_NOT_ACTIVE");
        presaleEditions.publicSale{value: 0.5 ether}(editionId, 1);
    }

    function testRevert_StandardInvalidBatchPrice() public {
        PresaleTypes.EditionData memory editionData = PresaleTypes.EditionData("Test", "TEST", "", "", 0, "", 0, 5, 10, creator);
        PresaleTypes.SaleData memory saleData = PresaleTypes.SaleData(
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            0.5 ether,
            1 ether,
            3,
            6,
            creator,
            defaultMerkleRoot
        );

        vm.prank(creator);
        uint256 editionId = presaleEditions.createPresaleEdition(editionData, saleData);

        vm.warp(2 days);
        vm.prank(presaleBuyer);
        vm.expectRevert("INVALID_PRICE");
        presaleEditions.publicSale{value: 0.5 ether}(editionId, 2);
    }

    /// ------------ WITHDRAW ------------ ///

    function testWithdraw(uint96 amount) public {
        vm.assume(amount < 100);
        PresaleTypes.EditionData memory editionData = PresaleTypes.EditionData("Test", "TEST", "", "", 0, "", 0, amount, 100, creator);
        PresaleTypes.SaleData memory saleData = PresaleTypes.SaleData(
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            0.5 ether,
            1 ether,
            100,
            200,
            creator,
            defaultMerkleRoot
        );

        vm.prank(creator);
        uint256 editionId = presaleEditions.createPresaleEdition(editionData, saleData);
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = bytes32(0x12e46814651febb3096e11596a99293a2279d73edd9935d9528163bc1360baa9);
        proof[1] = bytes32(0x29ec45f0409d89a93bb3d009b77ef1c24da4b04d81e7f149ff41fac10df8a942);

        vm.warp(1 days);
        vm.prank(presaleBuyer);
        presaleEditions.presale{value: amount * 0.5 ether}(editionId, amount, proof);

        uint256 beforeBalance = address(creator).balance;

        vm.prank(creator);
        presaleEditions.withdraw(editionId);

        uint256 afterBalance = address(creator).balance;
        require(afterBalance - beforeBalance == amount * 0.5 ether);
    }

    function testWithdrawMultiPurchase() public {
        PresaleTypes.EditionData memory editionData = PresaleTypes.EditionData("Test", "TEST", "", "", 0, "", 0, 5, 10, creator);
        PresaleTypes.SaleData memory saleData = PresaleTypes.SaleData(
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            0.5 ether,
            1 ether,
            3,
            6,
            creator,
            defaultMerkleRoot
        );

        vm.prank(creator);
        uint256 editionId = presaleEditions.createPresaleEdition(editionData, saleData);
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = bytes32(0x12e46814651febb3096e11596a99293a2279d73edd9935d9528163bc1360baa9);
        proof[1] = bytes32(0x29ec45f0409d89a93bb3d009b77ef1c24da4b04d81e7f149ff41fac10df8a942);

        vm.warp(1 days);
        vm.prank(presaleBuyer);
        presaleEditions.presale{value: 1 ether}(editionId, 2, proof);

        vm.warp(2 days);
        vm.prank(standardBuyer);
        presaleEditions.publicSale{value: 2 ether}(editionId, 2);

        uint256 beforeBalance = address(creator).balance;

        vm.prank(creator);
        presaleEditions.withdraw(editionId);

        uint256 afterBalance = address(creator).balance;
        require(afterBalance - beforeBalance == 3 ether);
    }

    function testWithdrawMultiEdition() public {
        PresaleTypes.EditionData memory editionData = PresaleTypes.EditionData("Test", "TEST", "", "", 0, "", 0, 5, 10, creator);
        PresaleTypes.SaleData memory saleData = PresaleTypes.SaleData(
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            0.5 ether,
            1 ether,
            3,
            6,
            creator,
            defaultMerkleRoot
        );
        PresaleTypes.SaleData memory secondSaleData = PresaleTypes.SaleData(
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            2 ether,
            4 ether,
            3,
            6,
            otherCreator,
            defaultMerkleRoot
        );

        vm.prank(creator);
        uint256 editionId = presaleEditions.createPresaleEdition(editionData, saleData);

        vm.prank(otherCreator);
        uint256 editionId2 = presaleEditions.createPresaleEdition(editionData, secondSaleData);

        bytes32[] memory proof = new bytes32[](2);
        proof[0] = bytes32(0x12e46814651febb3096e11596a99293a2279d73edd9935d9528163bc1360baa9);
        proof[1] = bytes32(0x29ec45f0409d89a93bb3d009b77ef1c24da4b04d81e7f149ff41fac10df8a942);

        vm.warp(1 days);
        vm.prank(presaleBuyer);
        presaleEditions.presale{value: 1 ether}(editionId, 2, proof);

        vm.prank(presaleBuyer);
        presaleEditions.presale{value: 4 ether}(editionId2, 2, proof);

        uint256 beforeBalance = address(creator).balance;

        vm.prank(creator);
        presaleEditions.withdraw(editionId);

        uint256 afterBalance = address(creator).balance;
        require(afterBalance - beforeBalance == 1 ether);

        beforeBalance = address(otherCreator).balance;

        vm.prank(otherCreator);
        presaleEditions.withdraw(editionId2);

        afterBalance = address(otherCreator).balance;
        require(afterBalance - beforeBalance == 4 ether);
    }

    function testDoubleWithdraw() public {
        PresaleTypes.EditionData memory editionData = PresaleTypes.EditionData("Test", "TEST", "", "", 0, "", 0, 5, 10, creator);
        PresaleTypes.SaleData memory saleData = PresaleTypes.SaleData(
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            0.5 ether,
            1 ether,
            3,
            6,
            creator,
            defaultMerkleRoot
        );

        vm.prank(creator);
        uint256 editionId = presaleEditions.createPresaleEdition(editionData, saleData);
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = bytes32(0x12e46814651febb3096e11596a99293a2279d73edd9935d9528163bc1360baa9);
        proof[1] = bytes32(0x29ec45f0409d89a93bb3d009b77ef1c24da4b04d81e7f149ff41fac10df8a942);

        vm.warp(1 days);
        vm.prank(presaleBuyer);
        presaleEditions.presale{value: 1 ether}(editionId, 2, proof);

        vm.warp(2 days);
        vm.prank(standardBuyer);
        presaleEditions.publicSale{value: 2 ether}(editionId, 2);

        uint256 beforeBalance = address(creator).balance;

        vm.prank(creator);
        presaleEditions.withdraw(editionId);

        uint256 afterBalance = address(creator).balance;
        require(afterBalance - beforeBalance == 3 ether);

        beforeBalance = address(creator).balance;

        vm.prank(creator);
        presaleEditions.withdraw(editionId);

        afterBalance = address(creator).balance;
        require(afterBalance - beforeBalance == 0 ether);
    }

    /// ------------ SETTERS ------------ ///

    function testSetters() public {
        PresaleTypes.EditionData memory editionData = PresaleTypes.EditionData("Test", "TEST", "", "", 0, "", 0, 5, 10, creator);
        PresaleTypes.SaleData memory saleData = PresaleTypes.SaleData(
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            0.5 ether,
            1 ether,
            3,
            6,
            creator,
            defaultMerkleRoot
        );
        PresaleTypes.SaleData memory update = PresaleTypes.SaleData(
            block.timestamp + 2 days,
            block.timestamp + 4 days,
            1 ether,
            2 ether,
            6,
            12,
            otherCreator,
            defaultMerkleRoot
        );

        vm.startPrank(creator);
        uint256 editionId = presaleEditions.createPresaleEdition(editionData, saleData);
        presaleEditions.setSaleData(editionId, update);

        (
            uint256 presaleStartTime,
            uint256 publicStartTime,
            uint256 presalePrice,
            uint256 standardPrice,
            uint256 maxMintsPerPresale,
            uint256 maxMintsPerPublicSale,
            address fundsRecipent,
            bytes32 merkleRoot
        ) = presaleEditions.editionIdToSaleData(editionId);

        require(presaleStartTime == block.timestamp + 2 days);
        require(publicStartTime == block.timestamp + 4 days);
        require(presalePrice == 1 ether);
        require(standardPrice == 2 ether);
        require(maxMintsPerPresale == 6);
        require(maxMintsPerPublicSale == 12);
        require(fundsRecipent == otherCreator);
        require(merkleRoot == defaultMerkleRoot);
        vm.stopPrank();
    }

    function testRevert_NotOwner() public {
        PresaleTypes.EditionData memory editionData = PresaleTypes.EditionData("Test", "TEST", "", "", 0, "", 0, 5, 10, creator);
        PresaleTypes.SaleData memory saleData = PresaleTypes.SaleData(
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            0.5 ether,
            1 ether,
            3,
            6,
            creator,
            defaultMerkleRoot
        );
        PresaleTypes.SaleData memory update = PresaleTypes.SaleData(
            block.timestamp + 2 days,
            block.timestamp + 4 days,
            1 ether,
            2 ether,
            6,
            12,
            otherCreator,
            defaultMerkleRoot
        );

        vm.prank(creator);
        uint256 editionId = presaleEditions.createPresaleEdition(editionData, saleData);

        vm.startPrank(otherCreator);
        vm.expectRevert("NOT_OWNER");
        presaleEditions.setSaleData(editionId, update);

        (
            uint256 presaleStartTime,
            uint256 publicStartTime,
            uint256 presalePrice,
            uint256 standardPrice,
            uint256 maxMintsPerPresale,
            uint256 maxMintsPerPublicSale,
            address fundsRecipent,
            bytes32 merkleRoot
        ) = presaleEditions.editionIdToSaleData(editionId);

        require(presaleStartTime == block.timestamp + 1 days);
        require(publicStartTime == block.timestamp + 2 days);
        require(presalePrice == 0.5 ether);
        require(standardPrice == 1 ether);
        require(maxMintsPerPresale == 3);
        require(maxMintsPerPublicSale == 6);
        require(fundsRecipent == creator);
        require(merkleRoot == defaultMerkleRoot);
        vm.stopPrank();
    }
}
