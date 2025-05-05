const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Hardhat Environment", function () {
  it("Should properly set up the Hardhat environment", async function () {
    // This is just a basic test to ensure the environment is working
    const [owner] = await ethers.getSigners();
    expect(owner.address).to.be.a('string');
    expect(owner.address).to.match(/^0x[0-9a-fA-F]{40}$/);
  });
});