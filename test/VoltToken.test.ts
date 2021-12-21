import { ethers, network } from "hardhat"
import { expect } from "chai"

describe("VoltToken", function () {
  before(async function () {
    this.VoltToken = await ethers.getContractFactory("VoltToken")
    this.signers = await ethers.getSigners()
    this.alice = this.signers[0]
    this.bob = this.signers[1]
    this.carol = this.signers[2]
  })

  beforeEach(async function () {
    this.volt = await this.VoltToken.deploy()
    await this.volt.deployed()
  })

  it("should have correct name and symbol and decimal", async function () {
    const name = await this.volt.name()
    const symbol = await this.volt.symbol()
    const decimals = await this.volt.decimals()
    expect(name).to.equal("VoltToken")
    expect(symbol).to.equal("VOLT")
    expect(decimals).to.equal(18)
  })

  it("should only allow owner to mint token", async function () {
    await this.volt.mint(this.alice.address, "100")
    await this.volt.mint(this.bob.address, "1000")
    await expect(this.volt.connect(this.bob).mint(this.carol.address, "1000", { from: this.bob.address })).to.be.revertedWith(
      "Ownable: caller is not the owner"
    )
    const totalSupply = await this.volt.totalSupply()
    const aliceBal = await this.volt.balanceOf(this.alice.address)
    const bobBal = await this.volt.balanceOf(this.bob.address)
    const carolBal = await this.volt.balanceOf(this.carol.address)
    expect(totalSupply).to.equal("1100")
    expect(aliceBal).to.equal("100")
    expect(bobBal).to.equal("1000")
    expect(carolBal).to.equal("0")
  })

  it("should supply token transfers properly", async function () {
    await this.volt.mint(this.alice.address, "100")
    await this.volt.mint(this.bob.address, "1000")
    await this.volt.transfer(this.carol.address, "10")
    await this.volt.connect(this.bob).transfer(this.carol.address, "100", {
      from: this.bob.address,
    })
    const totalSupply = await this.volt.totalSupply()
    const aliceBal = await this.volt.balanceOf(this.alice.address)
    const bobBal = await this.volt.balanceOf(this.bob.address)
    const carolBal = await this.volt.balanceOf(this.carol.address)
    expect(totalSupply).to.equal("1100")
    expect(aliceBal).to.equal("90")
    expect(bobBal).to.equal("900")
    expect(carolBal).to.equal("110")
  })

  it("should fail if you try to do bad transfers", async function () {
    await this.volt.mint(this.alice.address, "100")
    await expect(this.volt.transfer(this.carol.address, "110")).to.be.revertedWith("ERC20: transfer amount exceeds balance")
    await expect(this.volt.connect(this.bob).transfer(this.carol.address, "1", { from: this.bob.address })).to.be.revertedWith(
      "ERC20: transfer amount exceeds balance"
    )
  })

  it("should not exceed max supply of 10000m", async function () {
    await expect(this.volt.mint(this.alice.address, "10000000000000000000000000001")).to.be.revertedWith("VOLT::mint: cannot exceed max supply")
    await this.volt.mint(this.alice.address, "10000000000000000000000000000")
  })

  it("should not double spend delegation votes", async function () {
    await this.volt.mint(this.alice.address, "100")
    await this.volt.delegate(this.bob.address)

    await this.volt.transfer(this.carol.address, "100")
    await this.volt.connect(this.carol).delegate(this.bob.address)

    const votes = await this.volt.getCurrentVotes(this.bob.address)

    expect(votes).to.equal("100") // bob should have 100 votes instead of 200
  })

  after(async function () {
    await network.provider.request({
      method: "hardhat_reset",
      params: [],
    })
  })
})
