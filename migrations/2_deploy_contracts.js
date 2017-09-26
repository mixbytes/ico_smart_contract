'use strict';

const STQPreSale = artifacts.require("./STQPreSale.sol");

const preSaleWallet = '0x111';


module.exports = function(deployer, network) {
  deployer.deploy(STQPreSale, '0x2bD1F12269c1Ff80042c8D354BbA4C1Ca52e2061', preSaleWallet);

  // owners have to manually perform
  // STQToken.setController(address of STQPreSale);
};
