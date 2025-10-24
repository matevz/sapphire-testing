import { expect } from 'chai'
import { config, ethers } from 'hardhat'
import '@nomicfoundation/hardhat-chai-matchers'

describe('MyToken', function () {
  async function deployMyToken(name: string) {
    const MyToken_factory = await ethers.getContractFactory(name)
    const myToken = await MyToken_factory.deploy()
    await myToken.waitForDeployment()
    return myToken
  }

  it('MyToken', async function () {
    // Skip this test on non-sapphire chains.
    // On-chain encryption and/or signing required for SIWE.
    const myToken = await deployMyToken('MyToken')

    const signerAddress = await (await ethers.provider.getSigner(0)).getAddress()

    // Mint a new token and send it to me (the signer)
    await myToken.mint(signerAddress, 10)
    expect(await myToken.balanceOf(signerAddress)).to.equal(10)
  })

  it('MyTokenSelfDestruct', async function () {
    // Skip this test on non-sapphire chains.
    // On-chain encryption and/or signing required for SIWE.
    const myToken = await deployMyToken('MyTokenSelfDestruct')

    const signerAddress = await (await ethers.provider.getSigner(0)).getAddress()

    // Mint a new token and send it to me (the signer)
    expect(await myToken.mint(signerAddress, 10)).to.not.be.reverted
    expect(await myToken.balanceOf(signerAddress)).to.equal(10)

    expect(await myToken.destroy()).to.not.be.reverted

    expect(await myToken.mint(signerAddress, 10)).to.not.be.reverted
  })
})
