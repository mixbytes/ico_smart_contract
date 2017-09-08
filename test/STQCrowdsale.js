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

        // first investment at the first second, +25%
        await crowdsale.setTime(1505692800, {from: role.owner1});
        await crowdsale.sendTransaction({from: role.investor1, value: web3.toWei(20, 'finney')});
        await assertBalances(crowdsale, token, funds, web3.toWei(20, 'finney'));
        // remember: this is STQ balance
        assert.equal(await token.balanceOf(role.investor1), STQ(2.5));
        await expectThrow(crowdsale.sendTransaction({from: role.nobody, value: web3.toWei(0, 'finney')}));
        assert.equal(await token.balanceOf(role.nobody), STQ(0));

        // +5%
        await crowdsale.setTime(1506560000, {from: role.owner1});
        await crowdsale.sendTransaction({from: role.investor2, value: web3.toWei(100, 'finney')});
        await assertBalances(crowdsale, token, funds, web3.toWei(120, 'finney'));
        assert.equal(await token.balanceOf(role.investor1), STQ(2.5));
        assert.equal(await token.balanceOf(role.investor2), STQ(10.5));

        // 2nd investment of investor1
        await crowdsale.sendTransaction({from: role.investor1, value: web3.toWei(20, 'finney')});
        await assertBalances(crowdsale, token, funds, web3.toWei(140, 'finney'));
        assert.equal(await token.balanceOf(role.investor1), STQ(4.6));
        assert.equal(await token.balanceOf(role.investor2), STQ(10.5));

        // +0%
        await crowdsale.setTime(1507660000, {from: role.owner1});
        await crowdsale.sendTransaction({from: role.investor3, value: web3.toWei(40, 'finney')});
        await assertBalances(crowdsale, token, funds, web3.toWei(180, 'finney'));
        assert.equal(await token.balanceOf(role.investor1), STQ(4.6));
        assert.equal(await token.balanceOf(role.investor2), STQ(10.5));
        assert.equal(await token.balanceOf(role.investor3), STQ(4));
        await expectThrow(crowdsale.sendTransaction({from: role.nobody, value: web3.toWei(0, 'finney')}));

        // too late
        await crowdsale.setTime(1518660000, {from: role.owner1});
        await expectThrow(crowdsale.sendTransaction({from: role.investor1, value: web3.toWei(20, 'finney')}));
        await expectThrow(crowdsale.sendTransaction({from: role.nobody, value: web3.toWei(0, 'finney')}));
        assert.equal(await token.balanceOf(role.nobody), STQ(0));

        assert.equal(await token.totalSupply(), STQ(19.1));
    });


    it("test min cap", async function() {
        const role = getRoles();

        const [crowdsale, token, funds] = await instantiate();

        await crowdsale.setTime(1505692800, {from: role.owner1});
        await crowdsale.sendTransaction({from: role.investor1, value: web3.toWei(20, 'finney')});
        await crowdsale.setTime(1506560000, {from: role.owner1});   // +5%
        await crowdsale.sendTransaction({from: role.investor2, value: web3.toWei(60, 'finney')});
        await assertBalances(crowdsale, token, funds, web3.toWei(80, 'finney'));
        assert.equal(await token.balanceOf(role.investor1), STQ(2.5));
        assert.equal(await token.balanceOf(role.investor2), STQ(6.3));

        await crowdsale.setTime(1508371200, {from: role.owner1});
        await crowdsale.checkTime({from: role.owner1});

        assert.equal(await crowdsale.m_state(), 3);
        await expectThrow(crowdsale.sendTransaction({from: role.investor3, value: web3.toWei(40, 'finney')}));

        await expectThrow(funds.withdrawPayments({from: role.investor3}));
        await funds.withdrawPayments({from: role.investor2});
        await assertBalances(crowdsale, token, funds, web3.toWei(20, 'finney'));

        await expectThrow(funds.withdrawPayments({from: role.nobody}));
        await funds.sendEther(role.owner1, web3.toWei(20, 'finney'), {from: role.owner1});
        await expectThrow(funds.sendEther(role.owner1, web3.toWei(20, 'finney'), {from: role.owner2}));

        await funds.withdrawPayments({from: role.investor1});
        await assertBalances(crowdsale, token, funds, web3.toWei(0, 'finney'));
    });


    it("test minting for owners", async function() {
        const role = getRoles();

        let [crowdsale, token, funds] = await instantiate();

        await crowdsale.setTime(1505692800, {from: role.owner1});
        await crowdsale.sendTransaction({from: role.investor1, value: web3.toWei(20, 'finney')});
        await crowdsale.sendTransaction({from: role.investor2, value: web3.toWei(100, 'finney')});
        await assertBalances(crowdsale, token, funds, web3.toWei(120, 'finney'));
        assert.equal(await token.balanceOf(role.investor1), STQ(2.5));
        assert.equal(await token.balanceOf(role.investor2), STQ(12.5));
        assert.equal(await token.totalSupply(), STQ(15));

        await crowdsale.setTime(1508371200, {from: role.owner1});
        await crowdsale.checkTime({from: role.owner1});

        assert.equal(await token.balanceOf(role.owner1), STQ(20));
        assert.equal(await token.balanceOf(role.owner2), STQ(22.5));    // he is also investor1
        assert.equal(await token.balanceOf(role.owner3), STQ(20));
        assert.equal(await token.balanceOf(role.investor1), STQ(22.5)); // he is also owner2!
        assert.equal(await token.balanceOf(role.investor2), STQ(12.5));
        assert.equal(await token.totalSupply(), STQ(75));
        await assertBalances(crowdsale, token, funds, web3.toWei(120, 'finney'));

        // now, without owner-and-investor person

        [crowdsale, token, funds] = await instantiate();

        await crowdsale.setTime(1505692800, {from: role.owner1});
        await crowdsale.sendTransaction({from: role.investor2, value: web3.toWei(20, 'finney')});
        await crowdsale.sendTransaction({from: role.investor3, value: web3.toWei(100, 'finney')});
        await assertBalances(crowdsale, token, funds, web3.toWei(120, 'finney'));
        assert.equal(await token.balanceOf(role.investor2), STQ(2.5));
        assert.equal(await token.balanceOf(role.investor3), STQ(12.5));
        assert.equal(await token.totalSupply(), STQ(15));

        await crowdsale.setTime(1508371200, {from: role.owner1});
        await crowdsale.checkTime({from: role.owner1});

        assert.equal(await token.balanceOf(role.owner1), STQ(20));
        assert.equal(await token.balanceOf(role.owner2), STQ(20));
        assert.equal(await token.balanceOf(role.owner3), STQ(20));
        assert.equal(await token.balanceOf(role.investor2), STQ(2.5));
        assert.equal(await token.balanceOf(role.investor3), STQ(12.5));
        assert.equal(await token.totalSupply(), STQ(75));
        await assertBalances(crowdsale, token, funds, web3.toWei(120, 'finney'));
    });
});
