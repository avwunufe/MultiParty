// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract Multiparty {

    address[] public owners;

    address public immutable admin;

    mapping(address => bool) public isOwner;

    uint public percentageRequired = 60;

    mapping(uint => mapping(address => bool)) public isApproved;

    mapping(uint => address) public indexToOwner ;

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        uint numConfirmations;
    }

    // mapping from tx index => owner => bool
    

    Transaction[] public transactions;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }
    modifier onlyAdmin() {
        require(msg.sender == admin, "not admin");
        _;
    }
    modifier onlySubmitter(uint _txIndex) {
        require(indexToOwner[_txIndex] == msg.sender, "not owner");
        _;
    }

    modifier txExists(uint _txIndex) {
        require(_txIndex < transactions.length, "tx does not exist");
        _;
    }

    modifier notExecuted(uint _txIndex) {
        require(!transactions[_txIndex].executed, "tx already executed");
        _;
    }

    modifier notApproved(uint _txIndex) {
        require(!isApproved[_txIndex][msg.sender], "tx already confirmed");
        _;
    }

    constructor(address[] memory _owners, uint _percentageRequired) {
        require(_owners.length > 0, "owners required");
        require(
            _percentageRequired > 0, 
            "invalid percentage input"
        );

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner already added!");

            isOwner[owner] = true;
            owners.push(owner);
        }

        percentageRequired = _percentageRequired;
        admin = msg.sender;
    }

    function submitTransaction(
        address _to,
        uint _value,
        bytes memory _data
    ) public onlyOwner {

        uint txIndex = transactions.length;

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                numConfirmations: 0
            })
        );

        indexToOwner[txIndex] = msg.sender;

    }


    function approveProposal(uint _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notApproved(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations += 1;
        isApproved[_txIndex][msg.sender] = true;

    }

    function executeProposal(uint _txIndex)
        public
        onlySubmitter(_txIndex)
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        uint numberRequired = (owners.length * percentageRequired) / 100 ;
        require(
            transaction.numConfirmations >= numberRequired,
            "cannot execute tx"
        );

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "tx failed");

    }

    function addOwner(address _newOwner) public onlyAdmin {
        require(_newOwner != address(0), "invalid owner");
        require(!isOwner[_newOwner], "owner already added!");

        isOwner[_newOwner] = true;
        owners.push(_newOwner);
    }

    function removeOwner(uint _ownerIndex) public onlyAdmin {
        require(_ownerIndex < owners.length, "no owner exists at that index!");
        isOwner[owners[_ownerIndex]] = false;
        // Change owner at that index to address zero, rather than remove it to preserve integrity of the indexes of addressed stored after it
        owners[_ownerIndex] = address(0);
    }

    function changePercentageRequired(uint _newPercentage) public onlyAdmin {
        require(
            _newPercentage > 0, 
            "invalid percentage input"
        );
        percentageRequired = _newPercentage;
    }

}
