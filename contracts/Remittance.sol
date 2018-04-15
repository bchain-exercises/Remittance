pragma solidity ^0.4.21;

import "../node_modules/zeppelin-solidity/contracts/math/SafeMath.sol";
import "../node_modules/zeppelin-solidity/contracts/lifecycle/Destructible.sol";

contract Remittance {
    using SafeMath for uint256;
    
    enum ExchangeStatus {
        Unknown,
        Trusted,
        Blocked
    }
    
    struct RemittanceInfo {
        uint256 amount;
        uint256 revertPeriodStart;
    }
    
    uint256 public remittanceRevertDelay;
    mapping(address => ExchangeStatus) public exchanges;
    mapping(bytes32 => RemittanceInfo) public remittances;
    
    function Remittance(uint256 _remittanceRevertDelay) public {
        require(_remittanceRevertDelay > 0);

        remittanceRevertDelay = _remittanceRevertDelay;
    }
    
    function setExchangeStatus(address _exchange, ExchangeStatus _status) public onlyOwner {
        exchanges[_exchange] = _status;
    }

    // keccak256(senderPassHash, exchangePassHash, recipientAddress) => bytes32
    function createRemittance(bytes32 _remittanceDescriptionHash) public payable {
        bytes32 remittanceHash = keccak256(msg.sender, _remittanceDescriptionHash);
        
        // Remittance does not exist
        require(remittances[remittanceHash].revertPeriodStart == 0);
        require(msg.value > 0);
        
        uint256 remitAmount = msg.value;
        uint256 remitRevertPeriodStart = now.add(remittanceRevertDelay);
        
        remittances[remittanceHash] = RemittanceInfo(remitAmount, remitRevertPeriodStart);
    }
    
    // keccak256(senderPassHash, exchangePassHash, recipientAddress) => bytes32
    function revertRemittance(bytes32 _remittanceDescriptionHash) public {
        bytes32 remittanceHash = keccak256(msg.sender, _remittanceDescriptionHash);
        
        // Remittance can be reverted
        require(remittances[remittanceHash].revertPeriodStart > 0 && remittances[remittanceHash].revertPeriodStart < now);
        
        _transferRemittanceFunds(remittanceHash, msg.sender);
    }
    
    function withdrawRemittanceFunds(
        bytes32 _recipientPassHash,
        bytes32 _exchangePassHash,
        address _senderAddress,
        address _recipientAddress
    ) public {
        require(_recipientAddress == msg.sender || exchanges[msg.sender] == ExchangeStatus.Trusted);
        
        bytes32 remittanceDescriptionHash = keccak256(_recipientPassHash, _exchangePassHash, _recipientAddress);
        bytes32 remittanceHash = keccak256(_senderAddress, remittanceDescriptionHash);

        require(remittances[remittanceHash].amount > 0 && remittances[remittanceHash].revertPeriodStart > 0);
        
        _transferRemittanceFunds(remittanceHash, msg.sender);
    }
    
    function _transferRemittanceFunds(bytes32 _remittanceHash, address _beneficiary) internal {
        uint256 toSend = remittances[_remittanceHash].amount;
        
        delete remittances[_remittanceHash];
        
        _beneficiary.transfer(toSend);
    }    
}