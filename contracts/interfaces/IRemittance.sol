pragma solidity ^0.4.21;

interface IRemittance {
    function withdrawRemittanceFunds(
        bytes32 senderPassHash,
        bytes32 receiverPassHash,
        address senderAddress,
        address receiverAddress) public;
}