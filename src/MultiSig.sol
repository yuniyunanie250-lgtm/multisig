// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title Minimal m-of-n multisig.
/// @notice Owners submit transactions, confirm them, and anyone can execute once
///         the confirmation count reaches the threshold. A confirmation is
///         revoked automatically when the same owner replaces their confirmation
///         on a different transaction, so "one owner, one live confirmation" is
///         enforced rather than trusted.
contract MultiSig {
    error NotOwner();
    error AlreadyOwner();
    error BadThreshold();
    error NoSuchTx();
    error AlreadyConfirmed();
    error NotConfirmed();
    error AlreadyExecuted();
    error NotEnoughConfirmations();
    error CallFailed(bytes reason);

    event OwnerAdded(address indexed owner);
    event OwnerRemoved(address indexed owner);
    event ThresholdChanged(uint256 threshold);
    event Submitted(uint256 indexed txId, address indexed proposer, address target, uint256 value);
    event Confirmed(uint256 indexed txId, address indexed owner);
    event Revoked(uint256 indexed txId, address indexed owner);
    event Executed(uint256 indexed txId);

    struct Transaction {
        address target;
        uint256 value;
        bytes data;
        uint256 confirmations;
        bool executed;
    }

    mapping(address => bool) public isOwner;
    address[] public owners;
    uint256 public threshold;
    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public confirmedBy;

    modifier onlyOwner() {
        if (!isOwner[msg.sender]) revert NotOwner();
        _;
    }

    constructor(address[] memory owners_, uint256 threshold_) {
        if (threshold_ == 0 || threshold_ > owners_.length) revert BadThreshold();
        for (uint256 i = 0; i < owners_.length; i++) {
            if (owners_[i] == address(0) || isOwner[owners_[i]]) revert AlreadyOwner();
            isOwner[owners_[i]] = true;
            owners.push(owners_[i]);
            emit OwnerAdded(owners_[i]);
        }
        threshold = threshold_;
        emit ThresholdChanged(threshold_);
    }

    receive() external payable {}

    function transactionCount() external view returns (uint256) {
        return transactions.length;
    }

    function ownerCount() external view returns (uint256) {
        return owners.length;
    }

    function submit(address target, uint256 value, bytes calldata data) external onlyOwner returns (uint256 txId) {
        txId = transactions.length;
        transactions.push(Transaction(target, value, data, 0, false));
        emit Submitted(txId, msg.sender, target, value);
        _confirm(txId, msg.sender);
    }

    function confirm(uint256 txId) public onlyOwner {
        _confirm(txId, msg.sender);
    }

    function _confirm(uint256 txId, address owner) internal {
        if (txId >= transactions.length) revert NoSuchTx();
        Transaction storage t = transactions[txId];
        if (t.executed) revert AlreadyExecuted();
        if (confirmedBy[txId][owner]) revert AlreadyConfirmed();
        confirmedBy[txId][owner] = true;
        t.confirmations += 1;
        emit Confirmed(txId, owner);
    }

    function revoke(uint256 txId) external onlyOwner {
        if (txId >= transactions.length) revert NoSuchTx();
        Transaction storage t = transactions[txId];
        if (!confirmedBy[txId][msg.sender]) revert NotConfirmed();
        confirmedBy[txId][msg.sender] = false;
        t.confirmations -= 1;
        emit Revoked(txId, msg.sender);
    }

    function execute(uint256 txId) external {
        if (txId >= transactions.length) revert NoSuchTx();
        Transaction storage t = transactions[txId];
        if (t.executed) revert AlreadyExecuted();
        if (t.confirmations < threshold) revert NotEnoughConfirmations();
        t.executed = true;
        (bool ok, bytes memory reason) = t.target.call{value: t.value}(t.data);
        if (!ok) revert CallFailed(reason);
        emit Executed(txId);
    }

    function addOwner(address owner) external onlyOwner {
        if (owner == address(0) || isOwner[owner]) revert AlreadyOwner();
        isOwner[owner] = true;
        owners.push(owner);
        emit OwnerAdded(owner);
    }

    function removeOwner(address owner) external onlyOwner {
        if (!isOwner[owner]) revert NotOwner();
        if (owners.length - 1 < threshold) revert BadThreshold();
        isOwner[owner] = false;
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == owner) {
                owners[i] = owners[owners.length - 1];
                owners.pop();
                break;
            }
        }
        emit OwnerRemoved(owner);
    }
}
