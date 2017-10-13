pragma solidity 0.4.15;

import './STQPreICO.sol';


/// @title Storiqa pre-ICO contract
contract STQPreICO2 is STQPreICO {

    function STQPreICO2(address token, address funds) STQPreICO(token, funds) {
    }


    /// @notice maximum investments to be accepted during pre-ICO
    function getMaximumFunds() internal constant returns (uint) {
        return 8000 ether;
    }

    /// @notice start time of the pre-ICO
    function getStartTime() internal constant returns (uint) {
        return 1508349600;
    }

    /// @notice end time of the pre-ICO
    function getEndTime() internal constant returns (uint) {
        return getStartTime() + (1 days);
    }

    /// @notice pre-ICO bonus
    function getPreICOBonus() internal constant returns (uint) {
        return 35;
    }
}
