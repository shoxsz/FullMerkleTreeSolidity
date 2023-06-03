global.atob = str => Buffer.from(str, 'base64').toString('binary')
require("@nomicfoundation/hardhat-toolbox");
const { Identity } = require("@semaphore-protocol/identity");
const { Group } = require("@semaphore-protocol/group");
const { generateProof } = require("@semaphore-protocol/proof");
const env = require('dotenv').config().parsed;
const BN = require('bignumber.js')

task("deployMerkleTree", "Deploy a merkle tree")
  .setAction(async (_, hre) => {
    const merkleTree = await hre.ethers.getContractFactory(
      "FullMerkleTree",
      {
        libraries: {
          PoseidonT3: env.SEMAPHORE_POSEIDON
        }
      }
    );
    const mTree = await merkleTree.deploy();
    await mTree.deployed();
    console.log(`FullMerkleTree Library Deployed on address ${mTree.address}`)
  })

task("deployGroup", "Deploy a merkle tree")
  .setAction(async (_, hre) => {
    const group = await hre.ethers.getContractFactory(
      "FullMerkleTreeGroup",
      {
        libraries: {
          FullMerkleTree: env.FULL_MERKLE_TREE
        }
      }
    );
    const _group = await group.deploy();
    await _group.deployed();
    console.log(`Group Deployed on address ${_group.address}`)
  })

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      {
        version: '0.8.4',
        settings: {},
      },
      {
        version: '0.8.9',
        settings: {},
      },
    ],
  },
  networks: {
    arbitrum: {
      url: env.ARBITRUM_RPC,
      accounts: [env.ACCOUNT],
    }
  }
};
