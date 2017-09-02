pragma solidity 0.4.15;

import '../ownership/multiowned.sol';
import 'zeppelin-solidity/contracts/token/StandardToken.sol';


/// @title StandardToken which can be minted by another contract.
contract MintableMultiownedToken is multiowned, StandardToken {

    event Mint(address indexed to, uint256 amount);


    modifier onlyMinter {
        require(msg.sender == m_minter);
        _;
    }


    // PUBLIC interface

    function MintableMultiownedToken(address[] _owners, uint _signaturesRequired, address _minter)
        multiowned(_owners, _signaturesRequired)
    {
        m_minter = _minter;
    }

    /// @notice sets the minter
    function setMinter(address _minter) external onlymanyowners(sha3(msg.data)) {
        m_minter = _minter;
    }

    function mint(address _to, uint256 _amount) external onlyMinter {
        mintInternal(_to, _amount);
    }


    // INTERNAL functions

    function mintInternal(address _to, uint256 _amount) internal {
        totalSupply = totalSupply.add(_amount);
        balances[_to] = balances[_to].add(_amount);
        Mint(_to, _amount);
    }


    // FIELDS

    /// @notice address of entity entitled to mint new tokens
    address public m_minter;
}
