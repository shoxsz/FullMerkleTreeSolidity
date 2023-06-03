/// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./FullMerkleTree.sol";

contract FullMerkleTreeGroup {
  using FullMerkleTree for TreeData;

  address public owner;
  mapping(uint256 => TreeData) public merkleTrees;

  constructor () {
    owner = msg.sender;
  }

  function createGroup(uint256 groupId, uint256 merkleTreeDepth) public onlyOwner {
    require(merkleTrees[groupId].depth == 0, "Group already exists");

    uint256 zeroValue = uint256(keccak256(abi.encodePacked(groupId))) >> 8;

    merkleTrees[groupId].init(merkleTreeDepth, zeroValue);
  }

  function indexOf (uint256 groupId, uint256 identityCommitment) public view returns (uint256) {
    require(merkleTrees[groupId].depth != 0, "Group does not exist");

    return merkleTrees[groupId].indexOf(identityCommitment);
  }

  function getMembers (uint256 groupId) public view returns (uint256[] memory) {
    require(merkleTrees[groupId].depth != 0, "Group does not exist");

    return merkleTrees[groupId].getMembers();
  }

  function addMember(uint256 groupId, uint256 identityCommitment) public onlyOwner {
    require(merkleTrees[groupId].depth != 0, "Group does not exist");

    merkleTrees[groupId].insert(identityCommitment);
  }

  function updateMember(
    uint256 groupId,
    uint256 index,
    uint256 newIdentityCommitment
  ) public onlyOwner {
    require(merkleTrees[groupId].depth != 0, "Group does not exist");

    merkleTrees[groupId].update(index, newIdentityCommitment);
  }

  function removeMember(uint256 groupId, uint256 index) public onlyOwner {
    require(merkleTrees[groupId].depth != 0, "Group does not exist");

    merkleTrees[groupId].remove(index);
  }

  function getMerkleProof(uint256 groupId, uint256 index) public view onlyOwner returns (MerkleProof memory) {
    require(merkleTrees[groupId].depth != 0, "Group does not exist");

    return merkleTrees[groupId].getMerkleProof(index);
  }

  function verify(uint256 groupId, uint256 index, uint256[] memory siblings, uint8[] memory pathSiblings) public view onlyOwner returns (bool) {
    require(merkleTrees[groupId].depth != 0, "Group does not exist");

    return merkleTrees[groupId].verify(index, siblings, pathSiblings);
  }

  /** ALERT: Depending on group depth you wont be able to execute this function */
  function getNodes(uint256 groupId) public view returns (uint256[][] memory) {
    require(merkleTrees[groupId].depth != 0, "Group does not exist");
    uint256[][] memory nodes = new uint256[][](merkleTrees[groupId].depth + 1);
    for (uint i = 0; i < merkleTrees[groupId].depth;) {
      uint256 levelNodes = 2**(merkleTrees[groupId].depth - i);

      nodes[i] = new uint256[](levelNodes);
      for (uint j = 0; j < levelNodes;) {
        if (merkleTrees[groupId].nodes[i].length <= j)
          nodes[i][j] = merkleTrees[groupId].zeroes[i];
        else
          nodes[i][j] = merkleTrees[groupId].nodes[i][j];
        unchecked {
          ++j;
        }
      }
      unchecked {
        ++i;
      }
    }
    nodes[merkleTrees[groupId].depth] = new uint256[](1);
    nodes[merkleTrees[groupId].depth][0] = merkleTrees[groupId].root;
    return nodes;
  }

  modifier onlyOwner () {
    require(msg.sender == owner, "Only owner can call this function");
    _;
  }
}