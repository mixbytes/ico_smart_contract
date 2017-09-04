pragma solidity ^0.4.0;

import '../../contracts/crowdsale/FixedTimeBonuses.sol';
import 'truffle/Assert.sol';


contract Bonuses {
    using FixedTimeBonuses for FixedTimeBonuses.Data;

    function add(uint endTime, uint bonus) {
        m_bonuses.bonuses.push(FixedTimeBonuses.Bonus(endTime, bonus));
    }

    function validate(bool shouldDecrease) {
        m_bonuses.validate(shouldDecrease);
    }

    FixedTimeBonuses.Data m_bonuses;
}

contract TestFixedTimeBonuses {

    function testValidation() {
        Bonuses b = new Bonuses();
        b.add(1000000000, 50);
        b.validate(true);
    }
}
