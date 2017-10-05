'use strict';

const _owners = ['0xaF9Eca973ba1bf87923d45dCE471181F77DE301e', '0xc21afA07cE196500D45cD13B835645a2B05760e7', '0x7e71a0514D727A2828209CF74f05686f382e545D'];

const STQToken = artifacts.require("./STQToken.sol");
const STQPreSale = artifacts.require("./STQPreSale.sol");

const preSaleWallet = '0x0Eed5de3487aEC55bA585212DaEDF35104c27bAF';


module.exports = function(deployer, network) {
  deployer.deploy(STQToken, _owners).then(function() {
    return deployer.deploy(STQPreSale, STQToken.address, preSaleWallet);
  });

  // owners have to manually perform
  // STQToken.setController(address of STQPreSale);
};
