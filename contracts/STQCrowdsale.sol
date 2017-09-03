pragma solidity 0.4.15;

import './ownership/multiowned.sol';
import './crowdsale/FixedTimeBonuses.sol';
import './crowdsale/FundsRegistry.sol';
import './STQToken.sol';


/// @title Storiqa ICO contract
contract STQCrowdsale is multiowned {
    using FixedTimeBonuses for FixedTimeBonuses.Data;

    uint internal constant MSK2UTC_DELTA = 3600 * 3;

    enum IcoState { INIT, ICO, PAUSED, FAILED, SUCCEEDED }


    event StateChanged(IcoState indexed _state);
    event EtherSent(address indexed to, uint value);


    modifier requiresState(IcoState _state) {
        require(m_state == _state);
        _;
    }

    /// @dev triggers some state changes based on current time
    modifier timedStateChange() {
        if (IcoState.INIT == m_state && now >= getStartTime())
            changeState(IcoState.ICO);
        if (IcoState.ICO == m_state && now > getEndTime())
            finishICO();

        _;
    }


    // PUBLIC interface

    function STQCrowdsale(address[] _owners)
        multiowned(_owners, 2)
    {
        require(3 == _owners.length);
        m_token = new STQToken(_owners);
        m_funds = new FundsRegistry(_owners, 2, this);

        m_bonuses.bonuses.push(FixedTimeBonuses.Bonus({endTime: 1505768399 + MSK2UTC_DELTA, bonus: 25}));
        m_bonuses.bonuses.push(FixedTimeBonuses.Bonus({endTime: 1505941199 + MSK2UTC_DELTA, bonus: 20}));
        m_bonuses.bonuses.push(FixedTimeBonuses.Bonus({endTime: 1506200399 + MSK2UTC_DELTA, bonus: 15}));
        m_bonuses.bonuses.push(FixedTimeBonuses.Bonus({endTime: 1506545999 + MSK2UTC_DELTA, bonus: 10}));
        m_bonuses.bonuses.push(FixedTimeBonuses.Bonus({endTime: 1506891599 + MSK2UTC_DELTA, bonus: 5}));
        m_bonuses.bonuses.push(FixedTimeBonuses.Bonus({endTime: 1508360399 + MSK2UTC_DELTA, bonus: 0}));
        m_bonuses.validate(true);
    }


    // PUBLIC interface: payments

    // fallback function as a shortcut
    function() payable {
        buy();
    }

    /// @notice ICO participation
    /// @return number of STQ tokens bought (with all decimal symbols)
    function buy()
        public
        payable
        timedStateChange
        requiresState(IcoState.ICO)
        returns (uint)
    {
        assert(false);  // FIXME checks

        uint stq = calcSTQAmount(msg.value);
        m_token.mint(msg.sender, stq);

        return stq;
    }


    // PUBLIC interface: owners: maintenance

    /// @notice Send `value` of collected ether to address `to`
    function sendEther(address to, uint value)
        external
        timedStateChange
        requiresState(IcoState.SUCCEEDED)
        onlymanyowners(sha3(msg.data))
    {
        require(0 != to);
        require(value > 0 && this.balance >= value);
        to.transfer(value);
        EtherSent(to, value);
    }

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
        tick();
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
        timedStateChange
        requiresState(IcoState.PAUSED)
        onlymanyowners(sha3(msg.data))
    {
        require(0x0 != _token);
        m_token = STQToken(_token);
    }

    /// @notice explicit trigger for timed state changes
    function tick()
        public
        timedStateChange
        onlyowner
    {
    }


    // INTERNAL functions

    function finishICO() private; // FIXME

    /// @dev performs only allowed state transitions
    function changeState(IcoState _newState) private {
        assert(m_state != _newState);

        if (IcoState.INIT == m_state) {        assert(IcoState.ICO == _newState); }
        else if (IcoState.ICO == m_state) {    assert(IcoState.PAUSED == _newState || IcoState.FAILED == _newState || IcoState.SUCCEEDED == _newState); }
        else if (IcoState.PAUSED == m_state) { assert(IcoState.ICO == _newState || IcoState.FAILED == _newState); }
        else assert(false);

        m_state = _newState;
        // this should be tightly linked
        if (IcoState.SUCCEEDED == m_state)
        {
            m_funds.changeState(FundsRegistry.State.SUCCEEDED);
            m_token.startCirculation();
        }
        else if (IcoState.FAILED == m_state)
        {
            m_funds.changeState(FundsRegistry.State.REFUNDING);
        }

        StateChanged(m_state);
    }


    /// @dev calculates amount of STQ to which payer of _wei is entitled
    function calcSTQAmount(uint _wei) private constant returns (uint) {
        assert(false);  // FIXME
        m_bonuses.getBonus(now);
    }

    /// @dev start time of the ICO, inclusive
    function getStartTime() private constant returns (uint) {
        return m_startTime;
    }

    /// @dev end time of the ICO, inclusive
    function getEndTime() private constant returns (uint) {
        return m_bonuses.getLastTime();
    }


    // FIELDS

    /// @notice start time of the ICO
    uint public constant m_startTime = 1505682000 + MSK2UTC_DELTA;

    /// @notice timed bonuses
    FixedTimeBonuses.Data m_bonuses;

    /// @dev state of the ICO
    IcoState public m_state = IcoState.INIT;

    /// @dev contract responsible for token accounting
    STQToken public m_token;

    /// @dev contract responsible for investments accounting
    FundsRegistry public m_funds;
}
