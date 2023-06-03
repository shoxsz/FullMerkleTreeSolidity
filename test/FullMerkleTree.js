global.atob = str => Buffer.from(str, 'base64').toString('binary')
const { Identity } = require("@semaphore-protocol/identity");

const printTree = async (group) => {
  const nodes = await group.getNodes(0)
  const _nodes = [...nodes].reverse()
  _nodes.forEach(level => {
    console.log(level.map(node => `${node}`.slice(0, 4)).join(','))
  })
}

describe("FullMerkleTreeTests", function () {
  it("Tests", async function () {
    this.timeout(0);
    const PoseidonT3 = await hre.ethers.getContractFactory("PoseidonT3Lib");
    const poseidont3 = await PoseidonT3.deploy()
    await poseidont3.deployed();

    const merkleTree = await hre.ethers.getContractFactory(
      "FullMerkleTree",
      {
        libraries: {
          PoseidonT3: poseidont3.address
        }
      }
    );
    const mTree = await merkleTree.deploy();
    await mTree.deployed();
  
    const group = await hre.ethers.getContractFactory(
      "FullMerkleTreeGroup",
      {
        libraries: {
          FullMerkleTree: mTree.address
        }
      }
    );
    const _group = await group.deploy();
    await _group.deployed();

    const groupDepth = 32
    const groupTest = groupDepth > 8 ? (groupDepth > 16 ? Math.floor(0.0000001 * (2**groupDepth)) : Math.floor(0.01 * (2**groupDepth))) : 2**groupDepth
    const tx = await _group.createGroup(0, groupDepth, { gasLimit: 30000000 }).then(tx => tx.wait())
    const createGroupCost = `${tx.gasUsed}`
    console.log('Created group')
    // await printTree(_group)

    // const ids = Array(groupTest).fill().map((_, idx) => new Identity(`${idx}`).commitment)
    const ids = Array(groupTest).fill().map((_, idx) => idx)

    const addMembersCost = []
    console.log('Adding members')
    for (let i = 0; i < groupTest; ++i) {
      const addMemberTx = await _group.addMember(0, ids[i]).then(tx => tx.wait())
      addMembersCost.push(`${addMemberTx.gasUsed}`)
      console.log(`Added member ${ids[i]}  Gas Used ${addMemberTx.gasUsed}`)
    }

    const members = (await _group.getMembers(0)).map(member => `${member}`)
    const rmvMembersCost = []
    console.log('Removing members')
    for (let i = 0; i < groupTest; ++i) {
      // const index = await _group.indexOf(0, ids[i])
      const index = members.indexOf(`${ids[i]}`)
      const rmvMemberTx = await _group.removeMember(0, index).then(tx => tx.wait())
      rmvMembersCost.push(`${rmvMemberTx.gasUsed}`)
      console.log(`Removed member ${ids[i]} Gas Used ${rmvMemberTx.gasUsed}`)
    }

    // await printTree(_group)

    // const merkleProof = await _group.getMerkleProof(0, index)
    // const path = merkleProof.pathIndices.map(idx => idx.toString())

    console.log(`createGroupCost: ${createGroupCost}`)
    console.log(`Average addMember cost ${addMembersCost.reduce((a, b) => parseInt(a) + parseInt(b), 0) / addMembersCost.length}`)
    console.log(`Average rmvMember cost ${rmvMembersCost.reduce((a, b) => parseInt(a) + parseInt(b), 0) / rmvMembersCost.length}`)
  });

  // TODO: Add tests for semaphore poofs
})
