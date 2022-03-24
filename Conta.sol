pragma solidity ^0.5.2;

contract Deep {

  Room[] private rooms;
  User[] private users;
  
  uint[] private openRooms;

  struct User {
    address payable account;
    string name;
    uint16 pin;
  }

  struct Room {

    address[] accounts;
    uint8[] PRNs;
    uint8 cap;
    uint16 timer;
    uint ID;
    uint cost;
    uint timestamp;
    bool status;
  }

  mapping(address => uint) addressToUser;
  mapping(address => uint[]) addressToRoom;
  mapping(address => mapping(uint => bool)) prnSent;

  constructor(uint8 percent) public payable 
  ValidMinorEqual(percent, 7){
    users.length += 1;
    rooms.length += 1;

    users[0].account = msg.sender;
    rooms[0].cost = msg.value;
    rooms[0].timer = percent;
  }

  // function MODIFIERS //
  modifier ValidAddress() {
    require(msg.sender != address(0),
      'please provide a valid ETH address. Reverting');
    _;
  }

  modifier ValidRegistration(uint _id) {
    require(_id != 0,
      'requires an user on this smart contract. Reverting');
    _;
  }

  modifier ValidString(string memory _string, uint8 _limit) {
    require(bytes(_string).length != 0 && bytes(_string).length <= _limit,
      'value must not be empthy or greater than limit. Reverting');
    _;
  }

  modifier ValidMinorEqual(uint _uint, uint _limit) {
    require(_uint <= _limit,
      'values are greater than limit. Reverting');
    _;
  }
  
  modifier ValidBetween(uint _min, uint _uint, uint _limit) {
    require(_uint <= _limit && _min <= _uint,
      'wrong values input. Reverting');
    _;
  }

  modifier ValidEqual(uint _uint, uint _equal) {
    require(_uint == _equal,
      'values do not match. Reverting');
    _;
  }

  modifier ValidGreaterEqual(uint _uint, uint _limit) {
    require(_uint >= _limit,
      'values are smaller than minimum. Reverting');
    _;
  }

  modifier ValidGreater(uint _uint, uint _limit) {
    require(_uint > _limit,
      'values are smaller than minimum. Reverting');
    _;
  }

  modifier ValidBool(bool _bool) {
    require(_bool == true,
      'target is set to false. Reverting');
    _;
  }
  


  // public FUNCTIONS //
  function addUser(string calldata name, uint pin) external
  ValidAddress()
  ValidString(name, 16)
  ValidMinorEqual(pin, 9999)
  ValidEqual(addressToUser[msg.sender], 0) {

    _addUser(name, pin);

  }
  
  function askPIN(uint pin) view external 
  ValidRegistration(addressToUser[msg.sender]) 
  ValidEqual(users[addressToUser[msg.sender]].pin, pin) 
  returns (bool) {
    return true;
  }

  function editUser(string calldata name, uint pin, uint newPin) external
  ValidRegistration(addressToUser[msg.sender])
  ValidString(name, 16)
  ValidMinorEqual(pin, 9999) {

    _pushUser(name, pin, newPin);

  }

  function createRoom(uint cap, uint timer, uint prn) external payable
  ValidRegistration(addressToUser[msg.sender])
  ValidGreaterEqual(msg.value, rooms[0].cost)
  ValidBetween(33, timer, 25200)
  ValidBetween(2, cap, 10) 
  returns(uint){

    _addRoom(cap, timer, prn);
    return rooms.length;
    
  }

  function joinRoom(uint id) external payable
  ValidRegistration(id)
  ValidBool(rooms[id].status)
  ValidGreater(rooms[id].cap, rooms[id].accounts.length)
  ValidGreaterEqual(rooms[id].timer + rooms[id].timestamp, now)
  ValidEqual(msg.value, rooms[id].cost) {
      
      _pushRoom(id);
      
  }
  function sendPRN(uint prn, uint id) external 
  ValidRegistration(id)
  ValidGreaterEqual(rooms[id].timer + rooms[id].timestamp, now)
  ValidBetween(0, prn, 10) {
    
    
  }

  function close(uint id) external
  ValidBool(rooms[id].status)
  ValidMinorEqual(rooms[id].timer + rooms[id].timestamp, now) {

    _extract(id);

  }
  
  function getOpen() view external returns(uint[] memory)
  {
      return openRooms;
  }
  
  function getRoom(uint id) view external 
  ValidRegistration(id) 
  returns(uint, uint, uint, uint, uint, bool) {
      Room memory room = rooms[id];
      return (room.cost, 
              room.accounts.length,
              uint(room.cap),
              room.timestamp,
              uint(room.timer),
              room.status
              );
  }

  function getAccs(uint id) view external 
  returns(address[] memory) {
     if(msg.sender == users[0].account) {
          Room memory room = rooms[id];
          return room.accounts;
     } else {revert('not available. reverting');}
  }

  function getName() view external returns(string memory) {
    return users[addressToUser[msg.sender]].name;
  }
  
  function getMyRoom() view external returns(uint[] memory) {
      return addressToRoom[msg.sender];
  }

  // internal FUNCTIONS //
  function _addUser(string memory _name, uint _pin) internal {
    users.length += 1;
    uint i = users.length - 1;
    addressToUser[msg.sender] = i;
    users[i].account = msg.sender;
    users[i].name = _name;
    users[i].pin = uint16(_pin);
  }
  function _getName(address x) view public returns(string memory) {
      uint i = addressToUser[x];
      return users[i].name;
  }
  function _addRoom(uint _cap, uint _timer, uint prn) internal {
    uint i = rooms.length;
    addressToRoom[msg.sender].push(i);
    prnSent[msg.sender][i] = false;
    openRooms.push(i);
    Room memory room;
    room.cap=uint8(_cap);
    room.timer=uint16(_timer);
    room.timestamp=now;
    room.ID=i;
    room.cost=msg.value;
    room.status=true;
    rooms.push(room);
    rooms[rooms.length-1].accounts.push(msg.sender);
    _addPRN(i, prn);

  }
  
  function _addPRN(uint _id, uint _prn) internal {
    for (uint i = 0 ; i <= rooms[_id].accounts.length-1 ; i++) {
        if (rooms[_id].accounts[i] == msg.sender) {
              if(prnSent[msg.sender][_id] == true) {
                 revert('values already sent. reverting');
               }
               if(prnSent[msg.sender][_id] == false) {
  
                prnSent[msg.sender][_id] = true;
                rooms[_id].PRNs.length+1;
                rooms[_id].PRNs.push(uint8(_prn));
              }
              return;
        }
        if (i==rooms[_id].accounts.length-1) {
            revert('not in this instance. reverting');
        }
     }

  }

  function _pushUser(string memory _name, uint _pin, uint _newPin) internal {
    User storage user = users[addressToUser[msg.sender]];
    if (_pin == user.pin) {
      if (bytes(_name).length != 0) {
        user.name = _name;
      }
      if (_newPin != 0) {
        user.pin = uint16(_newPin);
      } else {
        return;
      }
    } else {
      revert('wrong pin. reverting');
    }
  }
  
  function _pushRoom(uint _id) internal {
    for (uint i = 0 ; i <= rooms[_id].accounts.length-1 ; i++) {
        if (rooms[_id].accounts[i] == msg.sender) {
            revert('already in this instance. reverting');
        }
        if (i==rooms[_id].accounts.length-1) {
            rooms[_id].accounts.push(msg.sender);

            addressToRoom[msg.sender].push(_id);
            prnSent[msg.sender][_id] = false;
        return;
        }

    }

  }

  function _extract(uint id) internal {

    uint y;
    uint z;

    for (uint i = 0; i < rooms[id].PRNs.length; i++) {
      z += uint(rooms[id].PRNs[i]);
    }
    for (uint i = 1; i < z; i++) {
      if (y < rooms[id].accounts.length-1) {
        y++;
      } else {
        y = 0;
      }
    }
        require(rooms[id].accounts[y] != address(0),
          'winner can not be null. Reverting');

        address winner = rooms[id].accounts[y];
        if (winner == users[addressToUser[winner]].account) {
          uint roomValue = rooms[id].cost * rooms[id].accounts.length;
          uint feeAmount = roomValue * uint(rooms[0].timer) / 100 ;
          uint winnerValue = roomValue - feeAmount;
          if (rooms[id].status == true) {
            rooms[id].status = false;
            _delOpen(id);
            address(this).balance - roomValue;
            users[0].account.transfer(feeAmount);
            users[addressToUser[winner]].account.transfer(winnerValue);

          } else {
            revert('bet was already closed. Reverting');
          }
        }
      
  }
  
  function _delOpen(uint id) internal {
    for(uint i=0; i < openRooms.length; i++) {
      if( openRooms[i] == id ) {
          delete openRooms[i];
      }
      if (openRooms[i] == 0) {
        openRooms[i] = openRooms[openRooms.length-1];
        openRooms.length--;
      }
    }
    return;
  }
}