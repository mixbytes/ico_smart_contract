// Code taken from https://github.com/ethereum/dapp-bin/blob/master/wallet/wallet.sol
// Audit, refactoring and improvements by github.com/Eenae

// @authors:
// Gav Wood <g@ethdev.com>
// inheritable "property" contract that enables methods to be protected by requiring the acquiescence of either a
// single, or, crucially, each of a number of, designated owners.
// usage:
// use modifiers onlyowner (just own owned) or onlymanyowners(hash), whereby the same hash must be provided by
// some number (specified in constructor) of the set of owners (specified in the constructor, modifiable) before the
// interior is executed.

pragma solidity ^0.4.10;

contract multiowned {

	// TYPES

    // struct for the status of a pending operation.
    struct PendingState {
        // count of confirmations needed
        uint yetNeeded;

        // bitmap of confirmations where owner #ownerIndex's decision corresponds to 2**ownerIndex bit
        uint ownersDone;

        // position of this operation key in m_pendingIndex
        uint index;
    }

	// EVENTS

    // this contract only has six types of events: it can accept a confirmation, in which case
    // we record owner and operation (hash) alongside it.
    event Confirmation(address owner, bytes32 operation);
    event Revoke(address owner, bytes32 operation);
    // some others are in the case of an owner changing.
    event OwnerChanged(address oldOwner, address newOwner);
    event OwnerAdded(address newOwner);
    event OwnerRemoved(address oldOwner);
    // the last one is emitted if the required signatures change
    event RequirementChanged(uint newRequirement);

	// MODIFIERS

    // simple single-sig function modifier.
    modifier onlyowner {
        require(isOwner(msg.sender));
        _;
    }
    // multi-sig function modifier: the operation must have an intrinsic hash in order
    // that later attempts can be realised as the same underlying operation and
    // thus count as confirmations.
    modifier onlymanyowners(bytes32 _operation) {
        if (confirmAndCheck(_operation)) {
            _;
        }
        // Even if required number of confirmations has't been collected yet,
        // we can't throw here - because changes to the state have to be preserved.
        // But, confirmAndCheck itself will throw in case sender is not an owner.
    }

    modifier validNumOwners(uint _numOwners) {
        require(_numOwners > 0 && _numOwners <= c_maxOwners);
        _;
    }

    modifier validRequirement(uint _required, uint _numOwners) {
        require(_required > 0 && _required <= _numOwners);
        _;
    }

    modifier ownerExists(address _address) {
        require(isOwner(_address));
        _;
    }

    modifier ownerDoesNotExist(address _address) {
        require(!isOwner(_address));
        _;
    }

    modifier operationIsActive(bytes32 _operation) {
        require(isOperationActive(_operation));
        _;
    }

	// METHODS

    // constructor is given number of sigs required to do protected "onlymanyowners" transactions
    // as well as the selection of extra addresses capable of confirming them (msg.sender also added to owners).
    function multiowned(address[] _extraOwners, uint _required)
        validNumOwners(_extraOwners.length + 1)
        validRequirement(_required, _extraOwners.length + 1)
    {
        assert(c_maxOwners <= 255);

        m_numOwners = _extraOwners.length + 1;
        m_required = _required;

        m_owners[1] = msg.sender;
        m_ownerIndex[msg.sender] = 1;
        for (uint i = 0; i < _extraOwners.length; ++i)
        {
            uint currentOwnerIndex = checkOwnerIndex(
                i
                + 1 /* first slot is unused */
                + 1 /* first owner is msg.sender */);
            m_owners[currentOwnerIndex] = _extraOwners[i];
            m_ownerIndex[_extraOwners[i]] = currentOwnerIndex;
        }

        assertOwnersAreConsistent();
    }

    // Replaces an owner `_from` with another `_to`.
    // All pending operations will be canceled!
    function changeOwner(address _from, address _to)
        external
        ownerExists(_from)
        ownerDoesNotExist(_to)
        onlymanyowners(sha3(msg.data))
    {
        assertOwnersAreConsistent();

        clearPending();
        uint ownerIndex = checkOwnerIndex(m_ownerIndex[_from]);
        m_owners[ownerIndex] = _to;
        m_ownerIndex[_from] = 0;
        m_ownerIndex[_to] = ownerIndex;

        assertOwnersAreConsistent();
        OwnerChanged(_from, _to);
    }

    // All pending operations will be canceled!
    function addOwner(address _owner)
        external
        ownerDoesNotExist(_owner)
        validNumOwners(m_numOwners + 1)
        onlymanyowners(sha3(msg.data))
    {
        assertOwnersAreConsistent();

        clearPending();
        m_numOwners++;
        m_owners[m_numOwners] = _owner;
        m_ownerIndex[_owner] = checkOwnerIndex(m_numOwners);

        assertOwnersAreConsistent();
        OwnerAdded(_owner);
    }

    // All pending operations will be canceled!
    function removeOwner(address _owner)
        external
        ownerExists(_owner)
        validNumOwners(m_numOwners - 1)
        validRequirement(m_required, m_numOwners - 1)
        onlymanyowners(sha3(msg.data))
    {
        assertOwnersAreConsistent();

        clearPending();
        uint ownerIndex = checkOwnerIndex(m_ownerIndex[_owner]);
        m_owners[ownerIndex] = 0;
        m_ownerIndex[_owner] = 0;
        //make sure m_numOwners is equal to the number of owners and always points to the last owner
        reorganizeOwners();

        assertOwnersAreConsistent();
        OwnerRemoved(_owner);
    }

    // All pending operations will be canceled!
    function changeRequirement(uint _newRequired)
        external
        validRequirement(_newRequired, m_numOwners)
        onlymanyowners(sha3(msg.data))
    {
        m_required = _newRequired;
        clearPending();
        RequirementChanged(_newRequired);
    }

    // Gets an owner by 0-indexed position
    function getOwner(uint ownerIndex) external constant returns (address) {
        return m_owners[ownerIndex + 1];
    }

    function isOwner(address _addr) constant returns (bool) {
        return m_ownerIndex[_addr] > 0;
    }

    // Tests ownership of the current caller.
    // It's advisable to call it by new owner to make sure that the same erroneous address is not copy-pasted to
    // addOwner/changeOwner and to isOwner.
    function amIOwner() external constant onlyowner returns (bool) {
        return true;
    }

    // Revokes a prior confirmation of the given operation
    function revoke(bytes32 _operation)
        external
        operationIsActive(_operation)
        onlyowner
    {
        uint ownerIndexBit = makeOwnerBitmapBit(msg.sender);
        var pending = m_pending[_operation];
        require(pending.ownersDone & ownerIndexBit > 0);

        assertOperationIsConsistent(_operation);

        pending.yetNeeded++;
        pending.ownersDone -= ownerIndexBit;

        assertOperationIsConsistent(_operation);
        Revoke(msg.sender, _operation);
    }

    function hasConfirmed(bytes32 _operation, address _owner)
        external
        constant
        operationIsActive(_operation)
        ownerExists(_owner)
        returns (bool)
    {
        return !(m_pending[_operation].ownersDone & makeOwnerBitmapBit(_owner) == 0);
    }

    // INTERNAL METHODS

    function confirmAndCheck(bytes32 _operation)
        private
        onlyowner
        returns (bool)
    {
        var pending = m_pending[_operation];

        // if we're not yet working on this operation, switch over and reset the confirmation status.
        if (! isOperationActive(_operation)) {
            // reset count of confirmations needed.
            pending.yetNeeded = m_required;
            // reset which owners have confirmed (none) - set our bitmap to 0.
            pending.ownersDone = 0;
            pending.index = m_pendingIndex.length++;
            m_pendingIndex[pending.index] = _operation;
            assertOperationIsConsistent(_operation);
        }

        // determine the bit to set for this owner.
        uint ownerIndexBit = makeOwnerBitmapBit(msg.sender);
        // make sure we (the message sender) haven't confirmed this operation previously.
        if (pending.ownersDone & ownerIndexBit == 0) {
            Confirmation(msg.sender, _operation);
            // ok - check if count is enough to go ahead.
            assert(pending.yetNeeded > 0);
            if (pending.yetNeeded == 1) {
                // enough confirmations: reset and run interior.
                delete m_pendingIndex[m_pending[_operation].index];
                delete m_pending[_operation];
                return true;
            }
            else
            {
                // not enough: record that this owner in particular confirmed.
                pending.yetNeeded--;
                pending.ownersDone |= ownerIndexBit;
                assertOperationIsConsistent(_operation);
            }
        }
    }

    // Reclaims free slots between valid owners in m_owners.
    // TODO given that its called after each removal, it could be simplified.
    function reorganizeOwners() private {
        uint free = 1;
        while (free < m_numOwners)
        {
            // iterating to the first free slot from the beginning
            while (free < m_numOwners && m_owners[free] != 0) free++;

            // iterating to the first occupied slot from the end
            while (m_numOwners > 1 && m_owners[m_numOwners] == 0) m_numOwners--;

            // swap, if possible, so free slot is located at the end after the swap
            if (free < m_numOwners && m_owners[m_numOwners] != 0 && m_owners[free] == 0)
            {
                // owners between swapped slots should't be renumbered - that saves a lot of gas
                m_owners[free] = m_owners[m_numOwners];
                m_ownerIndex[m_owners[free]] = free;
                m_owners[m_numOwners] = 0;
            }
        }
    }

    function clearPending() internal {
        uint length = m_pendingIndex.length;
        for (uint i = 0; i < length; ++i)
            if (m_pendingIndex[i] != 0)
                delete m_pending[m_pendingIndex[i]];
        delete m_pendingIndex;
    }

    function checkOwnerIndex(uint ownerIndex) private constant returns (uint) {
        assert(0 != ownerIndex && ownerIndex <= c_maxOwners);
        return ownerIndex;
    }

    function makeOwnerBitmapBit(address owner) private constant returns (uint) {
        uint ownerIndex = checkOwnerIndex(m_ownerIndex[owner]);
        return 2 ** ownerIndex;
    }

    function isOperationActive(bytes32 _operation) private constant returns (bool) {
        return 0 != m_pending[_operation].yetNeeded;
    }


    function assertOwnersAreConsistent() private constant {
        assert(m_numOwners > 0);
        assert(m_numOwners <= c_maxOwners);
        assert(m_owners[0] == 0);
        assert(0 != m_required && m_required <= m_numOwners);
    }

    function assertOperationIsConsistent(bytes32 _operation) private constant {
        var pending = m_pending[_operation];
        assert(0 != pending.yetNeeded);
        assert(m_pendingIndex[pending.index] == _operation);
        assert(pending.yetNeeded <= m_required);
    }


   	// FIELDS

    uint constant c_maxOwners = 250;

    // the number of owners that must confirm the same operation before it is run.
    uint public m_required;


    // pointer used to find a free slot in m_owners
    uint public m_numOwners;

    // list of owners (addresses),
    // slot 0 is unused so there are no owner which index is 0.
    // TODO could we save space at the end of the array for the common case of <10 owners? and should we?
    address[256] m_owners;

    // index on the list of owners to allow reverse lookup: owner address => index in m_owners
    mapping(address => uint) m_ownerIndex;


    // the ongoing operations.
    mapping(bytes32 => PendingState) m_pending;
    bytes32[] m_pendingIndex;
}
