'use strict';

import {l, logEvents} from '../helpers/debug';

const InvestmentAnalytics = artifacts.require("./crowdsale/InvestmentAnalyticsTestHelper.sol");
const AnalyticProxy = artifacts.require("AnalyticProxy");


contract('InvestmentAnalytics', function(accounts) {

    it("test simple", async function() {
        const instance = await InvestmentAnalytics.new({from: accounts[0]});
        await instance.createMorePaymentChannels(10, {from: accounts[0]});

        assert.equal(await instance.paymentChannelsCount(), 10);
        const paymentChannel1 = await instance.m_paymentChannels(1);
        const paymentChannel5 = await instance.m_paymentChannels(5);

        await AnalyticProxy.at(paymentChannel1).sendTransaction({from: accounts[1], value: web3.toWei(20, 'finney')});
        await AnalyticProxy.at(paymentChannel5).sendTransaction({from: accounts[2], value: web3.toWei(50, 'finney')});
        await AnalyticProxy.at(paymentChannel1).sendTransaction({from: accounts[3], value: web3.toWei(20, 'finney')});

        assert.equal(await instance.m_investmentsByPaymentChannel(paymentChannel1), web3.toWei(40, 'finney'));
        assert.equal(await instance.m_investmentsByPaymentChannel(paymentChannel5), web3.toWei(50, 'finney'));
    });
});
