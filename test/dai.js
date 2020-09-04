const { BN, ether, balance } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');
const { asyncForEach } = require('./utils');

// ABI
const daiABI = require('./abis/dai');

// userAddress must be unlocked using --unlock ADDRESS
const daiWhale = '0x9eb7f2591ed42dee9315b6e2aaf21ba85ea69f8c';
const daiAddress = '0x6b175474e89094c44da98b954eedeac495271d0f';
const daiContract = new web3.eth.Contract(daiABI, daiAddress);

contract('Truffle Mint DAI', async accounts => {
  it('should send ether to the DAI address', async () => {
    // Send 0.1 eth to userAddress to have gas to send an ERC20 tx.
    await web3.eth.sendTransaction({
      from: accounts[0],
      to: daiWhale,
      value: ether('0.1')
    });
    const ethBalance = await balance.current(daiWhale);
    expect(new BN(ethBalance)).to.be.bignumber.least(new BN(ether('0.1')));
  });

  it('should mint DAI for our first generated account', async () => {
    // Get 100 DAI for first account
      // daiAddress is passed to ganache-cli with flag `--unlock`
      // so we can use the `transfer` method
      await daiContract.methods
        .approve(accounts[0], ether('100').toString())
        .send({ from: daiWhale, gasLimit: 800000 });

       await daiContract.methods 
        .transferFrom(daiWhale, accounts[0], ether('100').toString())
        .send({ from: daiWhale, gasLimit: 800000 });
      const daiBalance = await daiContract.methods.balanceOf(accounts[0]).call();
      expect(new BN(daiBalance)).to.be.bignumber.least(ether('100'));
    });

  it('should mint DAI for our second generated account', async () => {
      // Get 100 DAI for first account
        // daiAddress is passed to ganache-cli with flag `--unlock`
        // so we can use the `transfer` method
      await daiContract.methods
        .approve(accounts[1], ether('100').toString())
        .send({ from: daiWhale, gasLimit: 800000 });
  
      await daiContract.methods 
        .transferFrom(daiWhale, accounts[0], ether('100').toString())
        .send({ from: daiWhale, gasLimit: 800000 });
      const daiBalance = await daiContract.methods.balanceOf(accounts[0]).call();
      expect(new BN(daiBalance)).to.be.bignumber.least(ether('100'));
    }); 
});
