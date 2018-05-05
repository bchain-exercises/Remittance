pragma solidity ^0.4.21;

import "./interfaces/ICurrency.sol";
import "./interfaces/IRemittance.sol";
import "../node_modules/zeppelin-solidity/contracts/math/SafeMath.sol";
import "../node_modules/zeppelin-solidity/contracts/lifecycle/Destructible.sol";

contract RemittanceExchange is Destructible {
    using SafeMath for uint256;
    
    IRemittance public remittance;
    uint256 public comission;
    
    mapping(address => uint256) public exchangeRates;
    mapping(address => mapping(bytes32 => ExchangedRemittance)) public convertedRemittances;
    
    struct ExchangedRemittance {
        address currency;
        uint256 amount;
    }    
    
    function RemittanceExchange(address _remittance, uint256 _exchangeComission) public {
        require(_remittance != address(0));
        
        remittance = IRemittance(_remittance);
        comission = _exchangeComission;
    }
    
    function setExchangeRate(address _currency, uint256 _unitWeiCost) public onlyOwner {
        require(_currency != address(0));

        exchangeRates[_currency] = _unitWeiCost;
    }

    function setExchangeComission(uint256 _exchangeComission) public onlyOwner {
        comission = _exchangeComission;
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
        
        uint256 remittanceAmount = newBalance.sub(oldBalance.add(comission));
        uint256 convertedRemittanceAmount = remittanceAmount.div(exchangeRates[_currency]);
        
        require(convertedRemittanceAmount != 0);
        
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

        delete convertedRemittances[msg.sender][_exchangedRemittanceHash];

        ICurrency currency = ICurrency(convertedRemittances[msg.sender][_exchangedRemittanceHash].currency);
        
        require(currency.transfer(msg.sender, toSend));
    }    
}