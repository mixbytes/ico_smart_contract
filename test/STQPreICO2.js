'use strict';

// testrpc has to be run as testrpc -u 0 -u 1 -u 2 -u 3 -u 4 -u 5

import {crowdsaleUTest} from './utest/Crowdsale';

const STQPreICO2 = artifacts.require("./test_helpers/STQPreICO2TestHelper.sol");
const STQToken = artifacts.require("./STQToken.sol");


contract('STQPreICO2', function(accounts) {

    async function instantiate(role) {
        const token = await STQToken.new([role.owner1, role.owner2, role.owner3], {from: role.nobody});
        const preICO = await STQPreICO2.new(token.address, role.cash, {from: role.nobody});
        preICO.transferOwnership(role.owner1, {from: role.nobody});

        await token.setController(preICO.address, {from: role.owner1});
        await token.setController(preICO.address, {from: role.owner2});

        return [preICO, token, role.cash];
    }


    for (const [name, fn] of crowdsaleUTest(accounts, instantiate, {
        extraPaymentFunction: 'buy',
        rate: 100000,
        startTime: (new Date('Wed, 18 Oct 2017 18:00:00 GMT')).getTime() / 1000,
        endTime: (new Date('Thu, 19 Oct 2017 18:00:00 GMT')).getTime() / 1000,
        maxTimeBonus: 35,
        firstPostICOTxFinishesSale: false,
        hasAnalytics: true,
        analyticsPaymentBonus: 2
    }))
        it(name, fn);
});
