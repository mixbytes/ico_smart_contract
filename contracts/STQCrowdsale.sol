pragma solidity 0.4.15;

import './ownership/multiowned.sol';
import './crowdsale/FixedTimeBonuses.sol';
import './crowdsale/FundsRegistry.sol';
import './crowdsale/InvestmentAnalytics.sol';
import './security/ArgumentsChecker.sol';
import './STQToken.sol';
import 'zeppelin-solidity/contracts/ReentrancyGuard.sol';
import 'zeppelin-solidity/contracts/math/Math.sol';
import 'zeppelin-solidity/contracts/math/SafeMath.sol';


/// @title Storiqa ICO contract
contract STQCrowdsale is ArgumentsChecker, ReentrancyGuard, multiowned, InvestmentAnalytics {
    using Math for uint256;
    using SafeMath for uint256;
    using FixedTimeBonuses for FixedTimeBonuses.Data;

    enum IcoState { INIT, ICO, PAUSED, FAILED, SUCCEEDED }


    event StateChanged(IcoState _state);
    event FundTransfer(address backer, uint amount, bool isContribution);


    modifier requiresState(IcoState _state) {
        require(m_state == _state);
        _;
    }

    /// @dev triggers some state changes based on current time
    /// note: function body could be skipped!
    modifier timedStateChange() {
        if (IcoState.INIT == m_state && getCurrentTime() >= getStartTime())
            changeState(IcoState.ICO);

        if (IcoState.ICO == m_state && getCurrentTime() > getEndTime()) {
            finishICO();

            if (msg.value > 0)
                msg.sender.transfer(msg.value);
            // note that execution of further (but not preceding!) modifiers and functions ends here
        } else {
            _;
        }
    }

    /// @dev automatic check for unaccounted withdrawals
    modifier fundsChecker() {
        assert(m_state == IcoState.ICO);

        uint atTheBeginning = m_funds.balance;
        if (atTheBeginning < m_lastFundsAmount) {
            changeState(IcoState.PAUSED);
            if (msg.value > 0)
                msg.sender.transfer(msg.value); // we cant throw (have to save state), so refunding this way
            // note that execution of further (but not preceding!) modifiers and functions ends here
        } else {
            _;

            if (m_funds.balance < atTheBeginning) {
                changeState(IcoState.PAUSED);
            } else {
                m_lastFundsAmount = m_funds.balance;
            }
        }
    }


    // PUBLIC interface

    function STQCrowdsale(address[] _owners, address _token, address _funds)
        multiowned(_owners, 2)
        validAddress(_token)
        validAddress(_funds)
    {
        require(3 == _owners.length);

        m_token = STQToken(_token);
        m_funds = FundsRegistry(_funds);

        m_bonuses.bonuses.push(FixedTimeBonuses.Bonus({endTime: c_startTime + (1 weeks), bonus: 30}));
        m_bonuses.bonuses.push(FixedTimeBonuses.Bonus({endTime: c_startTime + (2 weeks), bonus: 25}));
        m_bonuses.bonuses.push(FixedTimeBonuses.Bonus({endTime: c_startTime + (3 weeks), bonus: 20}));
        m_bonuses.bonuses.push(FixedTimeBonuses.Bonus({endTime: c_startTime + (4 weeks), bonus: 15}));
        m_bonuses.bonuses.push(FixedTimeBonuses.Bonus({endTime: c_startTime + (5 weeks), bonus: 10}));
        m_bonuses.bonuses.push(FixedTimeBonuses.Bonus({endTime: c_startTime + (8 weeks), bonus: 5}));
        m_bonuses.bonuses.push(FixedTimeBonuses.Bonus({endTime: 1514246400, bonus: 0}));
        m_bonuses.validate(true);
    }


    // PUBLIC interface: payments

    // fallback function as a shortcut
    function() payable {
        require(0 == msg.data.length);
        buy();  // only internal call here!
    }

    /// @notice ICO participation
    function buy() public payable {     // dont mark as external!
        iaOnInvested(msg.sender, msg.value, false);
    }

    function iaOnInvested(address investor, uint payment, bool usingPaymentChannel)
        internal
        nonReentrant
        timedStateChange
        fundsChecker
    {
        require(m_state == IcoState.ICO || m_state == IcoState.INIT && isOwner(investor) /* for final test */);

        require(payment >= c_MinInvestment);

        uint startingInvariant = this.balance.add(m_funds.balance);

        // checking for max cap
        uint fundsAllowed = getMaximumFunds().sub(getTotalInvested());
        assert(0 != fundsAllowed);  // in this case state must not be IcoState.ICO
        payment = fundsAllowed.min256(payment);
        uint256 change = msg.value.sub(payment);

        // issue tokens
        uint stq = calcSTQAmount(payment, usingPaymentChannel ? c_paymentChannelBonusPercent : 0);
        m_token.mint(investor, stq);

        // record payment
        m_funds.invested.value(payment)(investor);
        FundTransfer(investor, payment, true);

        // check if ICO must be closed early
        if (change > 0)
        {
            assert(getMaximumFunds() == getTotalInvested());
            finishICO();

            // send change
            investor.transfer(change);
            assert(startingInvariant == this.balance.add(m_funds.balance).add(change));
        }
        else
            assert(startingInvariant == this.balance.add(m_funds.balance));
    }


    // PUBLIC interface: owners: maintenance

    /// @notice pauses ICO
    function pause()
        external
        timedStateChange
        requiresState(IcoState.ICO)
        onlyowner
    {
        changeState(IcoState.PAUSED);
    }

    /// @notice resume paused ICO
    function unpause()
        external
        timedStateChange
        requiresState(IcoState.PAUSED)
        onlymanyowners(sha3(msg.data))
    {
        changeState(IcoState.ICO);
        checkTime();
    }

    /// @notice consider paused ICO as failed
    function fail()
        external
        timedStateChange
        requiresState(IcoState.PAUSED)
        onlymanyowners(sha3(msg.data))
    {
        changeState(IcoState.FAILED);
    }

    /// @notice In case we need to attach to existent token
    function setToken(address _token)
        external
        validAddress(_token)
        timedStateChange
        requiresState(IcoState.PAUSED)
        onlymanyowners(sha3(msg.data))
    {
        m_token = STQToken(_token);
    }

    /// @notice In case we need to attach to existent funds
    function setFundsRegistry(address _funds)
        external
        validAddress(_funds)
        timedStateChange
        requiresState(IcoState.PAUSED)
        onlymanyowners(sha3(msg.data))
    {
        m_funds = FundsRegistry(_funds);
    }

    /// @notice explicit trigger for timed state changes
    function checkTime()
        public
        timedStateChange
        onlyowner
    {
    }

    function createMorePaymentChannels(uint limit) external onlyowner returns (uint) {
        return createMorePaymentChannelsInternal(limit);
    }


    // INTERNAL functions

    function finishICO() private {
        if (getTotalInvested() < getMinFunds())
            changeState(IcoState.FAILED);
        else
            changeState(IcoState.SUCCEEDED);
    }

    /// @dev performs only allowed state transitions
    function changeState(IcoState _newState) private {
        assert(m_state != _newState);

        if (IcoState.INIT == m_state) {        assert(IcoState.ICO == _newState); }
        else if (IcoState.ICO == m_state) {    assert(IcoState.PAUSED == _newState || IcoState.FAILED == _newState || IcoState.SUCCEEDED == _newState); }
        else if (IcoState.PAUSED == m_state) { assert(IcoState.ICO == _newState || IcoState.FAILED == _newState); }
        else assert(false);

        m_state = _newState;
        StateChanged(m_state);

        // this should be tightly linked
        if (IcoState.SUCCEEDED == m_state) {
            onSuccess();
        } else if (IcoState.FAILED == m_state) {
            onFailure();
        }
    }

    function onSuccess() private {
        // mint tokens for owners
        uint tokensPerOwner = m_token.totalSupply().mul(4).div(m_numOwners);
        for (uint i = 0; i < m_numOwners; i++)
            m_token.mint(getOwner(i), tokensPerOwner);

        m_funds.changeState(FundsRegistry.State.SUCCEEDED);
        m_funds.detachController();

        m_token.disableMinting();
        m_token.startCirculation();
        m_token.detachController();
    }

    function onFailure() private {
        m_funds.changeState(FundsRegistry.State.REFUNDING);
        m_funds.detachController();
    }


    function getLargePaymentBonus(uint payment) private constant returns (uint) {
        if (payment > 5000 ether) return 20;
        if (payment > 3000 ether) return 15;
        if (payment > 1000 ether) return 10;
        if (payment > 800 ether) return 8;
        if (payment > 500 ether) return 5;
        if (payment > 200 ether) return 2;
        return 0;
    }

    /// @dev calculates amount of STQ to which payer of _wei is entitled
    function calcSTQAmount(uint _wei, uint extraBonus) private constant returns (uint) {
        uint stq = _wei.mul(c_STQperETH);

        uint bonus = extraBonus.add(m_bonuses.getBonus(getCurrentTime())).add(getLargePaymentBonus(_wei));

        // apply bonus
        stq = stq.mul(bonus.add(100)).div(100);

        return stq;
    }

    /// @dev start time of the ICO, inclusive
    function getStartTime() private constant returns (uint) {
        return c_startTime;
    }

    /// @dev end time of the ICO, inclusive
    function getEndTime() private constant returns (uint) {
        return m_bonuses.getLastTime();
    }

    /// @dev to be overridden in tests
    function getCurrentTime() internal constant returns (uint) {
        return now;
    }

    /// @dev to be overridden in tests
    function getMinFunds() internal constant returns (uint) {
        return c_MinFunds;
    }

    /// @dev to be overridden in tests
    function getMaximumFunds() internal constant returns (uint) {
        return c_MaximumFunds;
    }

    /// @dev amount of investments during all crowdsales
    function getTotalInvested() internal constant returns (uint) {
        return m_funds.totalInvested().add(2468 ether /* FIXME update me */);
    }


    // FIELDS

    /// @notice starting exchange rate of STQ
    uint public constant c_STQperETH = 100000;

    /// @notice minimum investment
    uint public constant c_MinInvestment = 10 finney;

    /// @notice minimum investments to consider ICO as a success
    uint public constant c_MinFunds = 30000 ether;

    /// @notice maximum investments to be accepted during ICO
    uint public constant c_MaximumFunds = 90000 ether;

    /// @notice start time of the ICO
    uint public constant c_startTime = 1508889600;

    /// @notice authorised payment bonus
    uint public constant c_paymentChannelBonusPercent = 2;

    /// @notice timed bonuses
    FixedTimeBonuses.Data m_bonuses;

    /// @dev state of the ICO
    IcoState public m_state = IcoState.INIT;

    /// @dev contract responsible for token accounting
    STQToken public m_token;

    /// @dev contract responsible for investments accounting
    FundsRegistry public m_funds;

    /// @dev last recorded funds
    uint256 public m_lastFundsAmount;
}
