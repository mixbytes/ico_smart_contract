'use strict';

// testrpc has to be run as testrpc -u 0 -u 1 -u 2 -u 3 -u 4 -u 5

import expectThrow from './helpers/expectThrow';
import {l, logEvents} from './helpers/debug';

const STQToken = artifacts.require("./STQToken.sol");
const FundsRegistry = artifacts.require("./crowdsale/FundsRegistry.sol");
const STQCrowdsale = artifacts.require("../test_helpers/STQCrowdsaleTestHelper.sol");


// Note: build artifact does not get rebuilt as STQCrowdsale changes (by some reason)
contract('STQCrowdsale', function(accounts) {

    function getRoles() {
        return {
            owner3: accounts[0],
            owner1: accounts[1],
            owner2: accounts[2],
            investor1: accounts[2],
            investor2: accounts[3],
            investor3: accounts[4],
            nobody: accounts[5]
        };
    }

    async function instantiate() {
        const role = getRoles();

        const funds = await FundsRegistry.new([role.owner1, role.owner2, role.owner3], 2, 0, {from: role.nobody});
        const token = await STQToken.new([role.owner1, role.owner2, role.owner3], {from: role.nobody});
        const crowdsale = await STQCrowdsale.new([role.owner1, role.owner2, role.owner3], token.address, funds.address, {from: role.nobody});

        await token.setController(crowdsale.address, {from: role.owner1});
        await token.setController(crowdsale.address, {from: role.owner2});

        await funds.setController(crowdsale.address, {from: role.owner1});
        await funds.setController(crowdsale.address, {from: role.owner2});

        return [crowdsale, token, funds];
    }

    async function assertBalances(crowdsale, token, funds, expected) {
        assert.equal(await web3.eth.getBalance(crowdsale.address), 0);
        assert.equal(await web3.eth.getBalance(token.address), 0);
        assert.equal(await web3.eth.getBalance(funds.address), expected);
    }

    // converts amount of STQ into STQ-wei
    function STQ(amount) {
        return web3.toWei(amount, 'ether');
    }


    it("test instantiation", async function() {
        const role = getRoles();

        const [crowdsale, token, funds] = await instantiate();

        assert.equal(await token.m_controller(), crowdsale.address);
        assert.equal(await funds.m_controller(), crowdsale.address);

        await assertBalances(crowdsale, token, funds, 0);
    });


    it("test investments", async function() {
        const role = getRoles();

        const [crowdsale, token, funds] = await instantiate();

        // too early!
        await crowdsale.setTime(1505592800, {from: role.owner1});
        await expectThrow(crowdsale.sendTransaction({from: role.investor1, value: web3.toWei(20, 'finney')}));
        await crowdsale.setTime(1505592799, {from: role.owner1});
        await expectThrow(crowdsale.sendTransaction({from: role.investor1, value: web3.toWei(20, 'finney')}));

        // first investment at the first second
        await crowdsale.setTime(1505692800, {from: role.owner1});
        await crowdsale.sendTransaction({from: role.investor1, value: web3.toWei(20, 'finney')});
        await assertBalances(crowdsale, token, funds, web3.toWei(20, 'finney'));
        // remember: this is STQ balance
        assert.equal(await token.balanceOf(role.investor1), STQ(2.5));
    });
});
