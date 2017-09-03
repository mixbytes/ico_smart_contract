pragma solidity 0.4.15;

import '../ownership/MultiownedControlled.sol';
import 'zeppelin-solidity/contracts/token/StandardToken.sol';


/// @title StandardToken which can be minted by another contract.
contract MintableMultiownedToken is MultiownedControlled, StandardToken {

    event Mint(address indexed to, uint256 amount);


    // PUBLIC interface

    function MintableMultiownedToken(address[] _owners, uint _signaturesRequired, address _minter)
        MultiownedControlled(_owners, _signaturesRequired, _minter)
    {
    }

    function mint(address _to, uint256 _amount) external onlyController {
        mintInternal(_to, _amount);
    }


    // INTERNAL functions

    function mintInternal(address _to, uint256 _amount) internal {
        totalSupply = totalSupply.add(_amount);
        balances[_to] = balances[_to].add(_amount);
        Mint(_to, _amount);
    }


    // FIELDS

}
