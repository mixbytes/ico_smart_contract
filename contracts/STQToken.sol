pragma solidity 0.4.15;

import './token/CirculatingToken.sol';
import './token/MintableMultiownedToken.sol';


/// @title Storiqa coin contract
contract STQToken is CirculatingToken, MintableMultiownedToken {


    // PUBLIC interface

    function STQToken(address[] _owners)
        MintableMultiownedToken(_owners, 2, /* minter: */ msg.sender)
    {
        require(3 == _owners.length);
    }

    function startCirculation() external onlyController {
        assert(enableCirculation());    // must be called once
    }


    // FIELDS

    string public constant name = 'Storiqa Token';
    string public constant symbol = 'STQ';
    uint8 public constant decimals = 18;
}
