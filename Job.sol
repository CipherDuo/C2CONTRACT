pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

contract Job {
    
    mapping(address => uint) allowedPersons; // Workers + Financer + Owner
    mapping(uint => Worker) Workers;
    uint workersLength; // Keeping track of workers
    address financer;
    address owner; // For avoid unpleasant situations

    struct Worker {
        address payable _address;
        uint _percentage; // 200 = 2%
    }

    enum Version {
        PATCH, // x.x.1
        MINOR, // x.1.x
        MAJOR // 1.x.x
    } 

    event versionData (
        bytes32 dagCid, // DagCid of update
        uint timeStamp, // For future get
        Version release // Type Of release
    );
    
    constructor(Worker[] memory _workers, address _financer) public {
        
        financer = _financer;
        owner = msg.sender;
        
        for(uint x = 0; x < _workers.length; x++) {
            allowedPersons[_workers[x]._address] = x+1;
            Workers[x] = Worker(
                {
                    _address: _workers[x]._address,
                    _percentage: _workers[x]._percentage
                }
            );
        }
        workersLength = _workers.length;
        allowedPersons[financer] = _workers.length-1;
        allowedPersons[owner] = _workers.length-1;
    }

    function releaseNewVersion(bytes32 _dagCid, uint256 _timeStamp, Version _version) external OnlyAllowed(allowedPersons[msg.sender])  {
        emit versionData(_dagCid, _timeStamp, _version);
    }

    //it doesn't work as expected // Percentage not working
    function sendMoney(uint256 amount) external OnlyFinancer() {
        require((amount / 10000 * 10000) == amount,"Amount too small");
        for(uint x = 0; x <= workersLength; x++) {
            address payable toSendMoney = Workers[x]._address;
            uint _percentage = Workers[x]._percentage;
            toSendMoney.transfer(amount * _percentage / 10000);
        }
    }
    
    function addMoney() external payable OnlyFinancer() {
        require(msg.value > 0, "Must be > 0");
    }
    
    
    function checkMoney() view external 
    OnlyAllowed(allowedPersons[msg.sender]) 
    returns(uint256) 
    {
        return address(this).balance;
    }
    
    function canAccess() view public returns(bool){ 
        if(allowedPersons[msg.sender] != 0) {
            return true;
        }else {
            return false;
        }
    }
    
    function checkFinancier() view external
    OnlyAllowed(allowedPersons[msg.sender])
    returns(address)
    {
        return financer;
    }
    
    modifier OnlyAllowed(uint _id) {
        require(_id != 0, "User isn't allowed");
        _;
    }
    
    modifier OnlyFinancer() {
        require(financer == msg.sender || owner == msg.sender, 'Only financer can do this!');
        _;
    }
    
    modifier onlyOwner() {
        require(owner == msg.sender, 'Only owner can do this!');
        _;
    }
    
  
}