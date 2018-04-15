pragma solidity ^0.4.21;

import "./interfaces/ICurrency.sol";
import "./interfaces/IRemittance.sol";
import "../node_modules/zeppelin-solidity/contracts/math/SafeMath.sol";
import "../node_modules/zeppelin-solidity/contracts/lifecycle/Destructible.sol";

contract RemittanceExchange is Destructible {
    using SafeMath for uint256;
    
    IRemittance private remittance;
    
    mapping(address => uint256) public exchangeRates;
    
    struct ExchangedRemittance {
        address currency;
        uint256 amount;
    }
    
    mapping(address => mapping(bytes32 => ExchangedRemittance)) public convertedRemittances;
    
    function RemittanceExchange(address _remittance) public {
        require(_remittance != address(0));
        
        remittance = IRemittance(_remittance);
    }
    
    function setExchangeRate(address _currency, uint256 _unitWeiCost) public onlyOwner {
        exchangeRates[_currency] = _unitWeiCost;
    }
    
    function convertRemittance(
        bytes32 _recipientPassHash,
        bytes32 _exchangePassHash,
        address _senderAddress,
        address _currency
    ) public returns(bytes32) {
        uint256 oldBalance = address(this).balance;
        remittance.withdrawRemittanceFunds(_recipientPassHash, _exchangePassHash, _senderAddress, msg.sender);
        uint256 newBalance = address(this).balance;
        
        require(newBalance > oldBalance);
        
        uint256 remittanceAmount = newBalance.sub(oldBalance);
        uint256 convertedRemittanceAmount = remittanceAmount.div(exchangeRates[_currency]);
        
        require(convertedRemittanceAmount != 0);
        
        // uint256 exchangeRemainder = remittanceAmount % exchangeRates[_currency];
        bytes32 exchangedRemittanceHash = keccak256(_currency, _recipientPassHash);
        
        convertedRemittances[msg.sender][exchangedRemittanceHash].currency = _currency;
        convertedRemittances[msg.sender][exchangedRemittanceHash].amount = convertedRemittances[msg.sender][exchangedRemittanceHash].amount.add(convertedRemittanceAmount);
        
        return exchangedRemittanceHash;
    }
    
    // keccak256(currency, recipientPassHash)
    function withdrawConvertedRemittance(bytes32 _exchangedRemittanceHash) public {
        require(convertedRemittances[msg.sender][_exchangedRemittanceHash].amount != 0);
        require(convertedRemittances[msg.sender][_exchangedRemittanceHash].currency != address(0));
        
        uint256 toSend = convertedRemittances[msg.sender][_exchangedRemittanceHash].amount;
        ICurrency currency = ICurrency(convertedRemittances[msg.sender][_exchangedRemittanceHash].currency);
        
        delete convertedRemittances[msg.sender][_exchangedRemittanceHash];
        
        require(currency.transfer(msg.sender, toSend));
    }    
}