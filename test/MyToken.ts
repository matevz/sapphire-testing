import { expect } from 'chai'
import { config, ethers } from 'hardhat'
import '@nomicfoundation/hardhat-chai-matchers'

describe('MyToken', function () {
  async function deployMyToken(name: string) {
    const MyToken_factory = await ethers.getContractFactory(name)
    const myToken = await MyToken_factory.deploy({gasLimit: 5000000})
    await myToken.waitForDeployment()
    return myToken
  }

  async function deployMessageBox() {
    const MessageBox_factory = await ethers.getContractFactory('MessageBox')
    const messageBox = await MessageBox_factory.deploy('localhost')
    await messageBox.waitForDeployment()
    return messageBox
  }


  it('MyToken', async function () {
    const myToken = await deployMyToken('MyToken')

    const signerAddress = await (await ethers.provider.getSigner(0)).getAddress()

    // Mint a new token and send it to me (the signer)
    await myToken.mint(signerAddress, 10)
    expect(await myToken.balanceOf(signerAddress)).to.equal(10)
  })

  it('MyTokenSelfDestruct', async function () {
    const myToken = await deployMyToken('MyTokenSelfDestruct')

    const signerAddress = await (await ethers.provider.getSigner(0)).getAddress()

    // Mint a new token and send it to me (the signer)
    expect(await myToken.mint(signerAddress, 10)).to.not.be.reverted
    expect(await myToken.destroy()).to.not.be.reverted
    expect(await myToken.mint(signerAddress, 10)).to.not.be.reverted
  })

  it('MyTokenIndirect', async function () {
    const myToken = await deployMyToken('MyTokenIndirect')
    //const myToken2 = await deployMyToken('MyToken')
    const messageBox = await deployMessageBox()

    // Mint a new token and send it to me (the signer)
//    await myToken2.mint(myToken.getAddress(), 10)
//    await myToken2.approve(await myToken.getAddress(), 10)
//    myToken.proxyTest(await myToken2.getAddress())
    myToken.proxyTest(await messageBox.getAddress())
  })

  it('MyTokenLuminex', async function () {
    this.timeout(600000)
    // const LuminexRouterV1_factory = await ethers.getContractFactory("LuminexRouterV1")
    // const r = await LuminexRouterV1_factory.deploy("0x1234567890123456789012345678901234567890", "0x1234567890123456789012345678901234567890")
    // await r.waitForDeployment()

    const myToken = await deployMyToken('MyTokenLuminex')
    for (var i=0; i<7; i++) // need to top up 601 key rings
    {
      await myToken.updateRingKey()
    }

    // Upstream transaction
    const txData = "0xe211ed5e000000000000000000000000ec240a739d04188d83e9125cecc2ea88fabd9b080000000000000000000000000000000000000000000000000000000008f0d180000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000002a0000000000000000000000000000000000000000000000000000000000000025900000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000230ea303f6dff93d40a3bcb2c56d972b5b282a1ed6a27784a69caa61244f4661538a133da1dc4918117c6d8a77810347aad7d0d6ccf543859b795447b393bb6e6b6fe348b551f999f61106603e4001ebf89966dc88b287fe413598f5e59954625242bae844c61ff73e70f3f861f15cc851d0fbd0a23ee19353854fe22dc56ddc8a9f562173617071a3df56b03f905fca175082ad4d32a75cc29d64ae147b11aa057a9a5a485ef640e11a8d67c9b15125b5dbde98121577c4645fcb51f060404c0bf709081efd96629eedf11945467a61a2eb107ddeac41463e6fb2769a49879fd4e4674869316c71d24f69ec20746ba272f0f33f5bc46a9ff177f3863a0c1ef88c99cdd14c95455f532765d5e7c18fa8176d8360103a1e1a557bb97ce7471cee9e46252373847fb798022a03796466442d11d88c8872c0241c5378d8f440e64fe5526ac2c13c1c056c321fb88888189493df6cffdb640ad980268f5960a57a3cdbf14903690118d31d2a0b992cd124cd24cb3181f13f523a3dad66578fabd8eb9e5557a01e2557069ebf69d8a9b5a94fcee83fdc4b268dd98ab417f52e58fb76a3282bef809db1f8ff2d073e185ae129675f05948770ed757df80456be5986ff45a7d99f50e15251f86cf441c8c5188d8c5f1eb2cf3f70f6655da022c8fbb2d12cf54033cb90b186fc8fb5f24216765559c81454b53b99dc66eae1f8daa02bcb0fa228a21da47663e121f3a029567b8213fedba46b5ebed3e663072c9cf9bf969a7d8622e1e6b85b9c99ed6d1baa6d494fc00000000000000000000000000000000"
    const signer = await ethers.provider.getSigner(0)
    const receipt = await(await signer.sendTransaction({
      to: await myToken.getAddress(),
      data: txData,
      value: 0
    })).wait()
    expect(receipt?.status).to.equal(1)
    // Mint a new token and send it to me (the signer)
    //await myToken.proxyPass("0x1234567890123456789012345678901234567890", 100, ethers.toUtf8Bytes("abc"))
  })
})
