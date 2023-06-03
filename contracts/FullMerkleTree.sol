/// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import {PoseidonT3} from "./Hashes.sol";
import "hardhat/console.sol";

struct TreeData {
  uint256 depth;
  uint256 root;
  uint256 numberOfLeaves;
  uint256 zeroValue;
  uint256[] zeroes;
  mapping(uint256 => uint256[]) nodes;
}

struct MerkleProof {
  uint256 root;
  uint256 leaf;
  uint256[] pathIndices;
  uint256[] siblings;
}

library FullMerkleTree {
  uint8 internal constant MAX_DEPTH = 32;
  uint256 internal constant SNARK_SCALAR_FIELD = 21888242871839275222246405745257275088548364400416034343698204186575808495617;

  function init (TreeData storage self, uint256 depth, uint256 zero) public {
    require(self.root == 0, "FullMerkleTree: already initialized");
    require(zero < SNARK_SCALAR_FIELD, "FullMerkleTree: leaf must be < SNARK_SCALAR_FIELD");
    require(depth > 0 && depth <= MAX_DEPTH, "FullMerkleTree: tree depth must be between 1 and 32");

    self.zeroValue = zero;
    self.zeroes = new uint256[](depth);
    for (uint256 i = 0; i < depth;) {
      // TOO EXPENSIVE
      // uint256 levelNodes = 2**(depth - i);
      // self.nodes[i] = new uint256[](levelNodes);
      // for (uint256 j = 0; j < levelNodes; j++) {
      //   self.nodes[i][j] = zero;
      // }
      // USE THIS INSTEAD
      self.nodes[i] = new uint256[](0);
      self.zeroes[i] = zero;
      zero = PoseidonT3.poseidon([zero, zero]);
      unchecked {
        ++i;
      }
    }
    self.root = zero;
    self.depth = depth;
  }

  function indexOf (TreeData storage self, uint256 leaf) public view returns (uint256) {
    for (uint256 i = 0; i < self.nodes[0].length; i++) {
      if (self.nodes[0][i] == leaf) return i;
    }
    revert ("MerkleTree: leaf not found");
  }

  function getMembers (TreeData storage self) public view returns (uint256[] memory) {
    return self.nodes[0]; // use this to get the nodes, you will have to compare with the self.zeroes to get the actual members
  }

  function insert (TreeData storage self, uint256 leaf) public {
    if (self.root == 0) revert("MerkleTree: Not initialized");
    uint256 depth = self.depth;

    require(leaf < SNARK_SCALAR_FIELD, "IncrementalBinaryTree: leaf must be < SNARK_SCALAR_FIELD");
    require(self.numberOfLeaves < 2**depth, "IncrementalBinaryTree: tree is full");

    uint256 index = self.numberOfLeaves;
    uint256 hash = leaf;

    for (uint256 i = 0; i < depth;) {
      if (self.nodes[i].length <= index) self.nodes[i].push(hash);
      else self.nodes[i][index] = hash;

      if (index & 1 == 0) {
        if (self.nodes[i].length <= index + 1)
          hash = PoseidonT3.poseidon([hash, self.zeroes[i]]);
        else
          hash = PoseidonT3.poseidon([hash, self.nodes[i][index + 1]]);
      } else {
        hash = PoseidonT3.poseidon([self.nodes[i][index - 1], hash]);
      }

      unchecked {
        ++i;
        index = index / 2;
      }
    }

    self.root = hash;
    self.numberOfLeaves += 1;
  }

  function update (TreeData storage self, uint256 index, uint256 newLeaf) public {
    if (self.root == 0) revert("MerkleTree: Not initialized");
    uint256 depth = self.depth;

    require(index < self.numberOfLeaves, "FullMerkleTree: index out of bounds");
    require(newLeaf < SNARK_SCALAR_FIELD, "FullMerkleTree: leaf must be < SNARK_SCALAR_FIELD");

    uint256 hash = newLeaf;

    for (uint256 i = 0; i < depth;) {
      if (self.nodes[i].length <= index) self.nodes[i].push(hash);
      else self.nodes[i][index] = hash;

      if (index & 1 == 0) {
        if (self.nodes[i].length <= index + 1)
          hash = PoseidonT3.poseidon([hash, self.zeroes[i]]);
        else
          hash = PoseidonT3.poseidon([hash, self.nodes[i][index + 1]]);
      } else {
        hash = PoseidonT3.poseidon([self.nodes[i][index - 1], hash]);
      }

      unchecked {
        ++i;
        index = index / 2;
      }
    }

    self.root = hash;
    self.numberOfLeaves += 1;
  }

  function remove (TreeData storage self, uint256 index) public {
    update(self, index, self.zeroValue);
    self.numberOfLeaves -= 1;
  }

  function getMerkleProof (TreeData storage self, uint256 index) public view returns (MerkleProof memory) {
    require(index < self.numberOfLeaves, "FullMerkleTree: index out of bounds");

    uint256 depth = self.depth;
    uint256[] memory siblings = new uint256[](depth);
    uint256[] memory pathIndices = new uint256[](depth);

    uint256 hash = self.nodes[0][index];
    uint256 siblingIndex = index;

    for (uint256 i = 0; i < depth;) {
      if (siblingIndex & 1 == 0) {
        if (self.nodes[i].length <= siblingIndex + 1)
          siblings[i] = self.zeroes[i];
        else
          siblings[i] = self.nodes[i][siblingIndex + 1];
        pathIndices[i] = 0;
      } else {
        siblings[i] = self.nodes[i][siblingIndex - 1];
        pathIndices[i] = 1;
      }

      unchecked {
        ++i;
        siblingIndex = siblingIndex / 2;
      }
    }

    return MerkleProof(self.root, hash, pathIndices, siblings);
  }

  function verify (TreeData storage self, uint256 index, uint256[] memory siblings, uint8[] memory pathSiblings) public view returns (bool) {
    require(index < self.numberOfLeaves, "FullMerkleTree: index out of bounds");
    require(siblings.length == self.depth, "FullMerkleTree: invalid number of siblings");
    require(pathSiblings.length == self.depth, "FullMerkleTree: invalid number of path siblings");

    uint256 depth = self.depth;
    uint256 hash = self.nodes[0][index];
    uint256 siblingIndex = index;

    for (uint256 i = 0; i < depth;) {
      // verify if path siblings are 0 or 1
      require(pathSiblings[i] == 0 || pathSiblings[i] == 1, "FullMerkleTree: invalid path sibling");
      if (pathSiblings[i] == 0) {
        hash = PoseidonT3.poseidon([hash, siblings[i]]);
      } else {
        hash = PoseidonT3.poseidon([siblings[i], hash]);
      }

      unchecked {
        ++i;
        siblingIndex = siblingIndex / 2;
      }
    }

    return hash == self.root;
  }
}