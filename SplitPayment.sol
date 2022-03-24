pragma solidity ^0.6.2;

import "github:OpenZeppelin/openzeppelin-contracts/contracts/access/Ownable.sol";

contract SplitPayments is Ownable {
    
    address payable[]  units;
    
    event Donation(address from, uint value);
    
    constructor(address payable[] memory  _units) Ownable() public
    {
        //units = new address[](_units.length);
        units = _units;
    }
    
    fallback() external payable
    {
        uint avrg = msg.value/units.length;
        split(avrg);
    }
    
    receive() external payable
    {
        split(msg.value);
        emit Donation(msg.sender, msg.value);
    }
    
    function split(uint value) internal
    {
        for(uint i=0; i<units.length; i++)
        {
            units[i].transfer(value);
        }
    }
    
    function unitsGet() view external returns(address payable[] memory)
    {
        return units;
    }
}