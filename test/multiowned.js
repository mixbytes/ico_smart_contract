'use strict';

// testrpc has to be run as testrpc -u 0 -u 1 -u 2 -u 3

import expectThrow from './helpers/expectThrow';

const multiowned = artifacts.require("./multiowned.sol");
const l = console.log;

contract('multiowned', function(accounts) {

    async function freshInstance(required=2) {
        return multiowned.new([accounts[1], accounts[2]], required, {from: accounts[0]});
    }

    async function getOwners(instance) {
        const totalOwners = (await instance.m_numOwners()).toNumber();
        const calls = [];
        for (let i = 0; i < totalOwners; i++)
            calls.push(instance.getOwner(i));
        return Promise.all(calls);
    }

    it("ctor check", async function() {
        await expectThrow(multiowned.new([accounts[1], accounts[2]], 20, {from: accounts[0]}));

        let instance = await multiowned.new([], 1, {from: accounts[0]});
        assert.deepEqual(await getOwners(instance), [accounts[0]]);

        instance = await multiowned.new([accounts[1]], 2, {from: accounts[0]});
        assert.deepEqual(await getOwners(instance), [accounts[0], accounts[1]]);

        instance = await freshInstance();
        assert.deepEqual(await getOwners(instance), [accounts[0], accounts[1], accounts[2]]);
    });

    it("changeOwner check", async function() {
        const instance = await freshInstance(1);

        await expectThrow(instance.changeOwner(accounts[1], accounts[3], {from: accounts[3]}));

        await expectThrow(instance.changeOwner('0x0000000000000000000000000000000000000012', accounts[3], {from: accounts[0]}));
        await expectThrow(instance.changeOwner(accounts[1], accounts[2], {from: accounts[0]}));

        await instance.changeOwner(accounts[1], accounts[3], {from: accounts[0]});
        assert.deepEqual(await getOwners(instance), [accounts[0], accounts[3], accounts[2]]);
    });

    it("double-signed changeOwner check", async function() {
        const instance = await freshInstance();

        // first signature
        await instance.changeOwner(accounts[1], accounts[3], {from: accounts[0]});
        assert.deepEqual(await getOwners(instance), [accounts[0], accounts[1], accounts[2]],
            'owners are the same');

        // makes no sense to sign again, accounts[0]!
        await instance.changeOwner(accounts[1], accounts[3], {from: accounts[0]});
        assert.deepEqual(await getOwners(instance), [accounts[0], accounts[1], accounts[2]],
            'owners are the same');

        // second signature
        await instance.changeOwner(accounts[1], accounts[3], {from: accounts[2]});
        assert.deepEqual(await getOwners(instance), [accounts[0], accounts[3], accounts[2]],
            'owners has been changed');
    });

    it("addOwner check", async function() {
        const instance = await freshInstance(1);

        await expectThrow(instance.addOwner(accounts[3], {from: accounts[3]}));
        await expectThrow(instance.addOwner(accounts[1], {from: accounts[0]}));

        await instance.addOwner(accounts[3], {from: accounts[0]});
        assert.deepEqual(await getOwners(instance), [accounts[0], accounts[1], accounts[2], accounts[3]]);
    });

    it("removeOwner check", async function() {
        const instance = await freshInstance(1);

        await expectThrow(instance.removeOwner(accounts[1], {from: accounts[3]}));
        await expectThrow(instance.removeOwner(accounts[3], {from: accounts[0]}));

        await instance.removeOwner(accounts[1], {from: accounts[0]});
        assert.deepEqual(await getOwners(instance), [accounts[0], accounts[2]]);
    });


    it("isOwner check", async function() {
        const instance = await freshInstance();

        assert(await instance.isOwner(accounts[0]));
        assert(await instance.isOwner(accounts[1]));
        assert(await instance.isOwner(accounts[2]));

        assert(false === (await instance.isOwner(accounts[3])));
        assert(false === (await instance.isOwner('0x12')));
    });

    it("amIOwner check", async function() {
        const instance = await freshInstance();

        assert(await instance.amIOwner({from: accounts[0]}));
        assert(await instance.amIOwner({from: accounts[1]}));
        assert(await instance.amIOwner({from: accounts[2]}));

        await expectThrow(instance.amIOwner({from: accounts[3]}));
        await expectThrow(instance.amIOwner({from: '0x0000000000000000000000000000000000000012'}));
    });

    it("changeRequirement check", async function() {
        const instance = await freshInstance(1);

        await expectThrow(instance.changeRequirement(2, {from: accounts[3]}));

        await expectThrow(instance.changeRequirement(0, {from: accounts[0]}));
        await expectThrow(instance.changeRequirement(4, {from: accounts[0]}));

        await instance.changeRequirement(3, {from: accounts[0]});
        assert.equal(await instance.m_required(), 3);
    });

});
