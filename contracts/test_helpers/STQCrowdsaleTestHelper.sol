pragma solidity 0.4.15;

import '../STQCrowdsale.sol';
import '../TestC.sol';


/// @title Test helper for STQCrowdsale, DONT use it in production!
contract STQCrowdsaleTestHelper is STQCrowdsale {

    function STQCrowdsaleTestHelper(address[] _owners, address _token, address _funds)
        STQCrowdsale(_owners, _token, _funds)
    {
    }

    function getCurrentTime() internal constant returns (uint) {
        return m_time;
    }

    function setTime(uint time) external onlyowner {
        m_time = time;
    }

    uint m_time;
}
