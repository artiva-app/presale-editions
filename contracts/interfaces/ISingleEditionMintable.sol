// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface ISingleEditionMintable {
  function setApprovedMinter(address minter, bool allowed) external;
  function mintEdition(address to) external returns (uint256);
  function transferOwnership(address newOwner) external;
  function owner() external view returns (address);
}