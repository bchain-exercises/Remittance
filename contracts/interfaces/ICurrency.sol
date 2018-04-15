pragma solidity ^0.4.21;

interface ICurrency {
    function transfer(address to, uint tokens) public returns (bool success);
}