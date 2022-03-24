pragma solidity ^0.6.2;
pragma experimental ABIEncoderV2;

import "github:OpenZeppelin/openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import "github:OpenZeppelin/openzeppelin-contracts/contracts/access/Ownable.sol";
import "./../cypherDuo/SplitPayment.sol";
import "./../cypherDuo/Inventory.sol";

contract Factory
{

    /////////////////
    /// VARIABLES ///
    /////////////////

    address vault;
        
    // used to match inventoryAddress to tokenID to owner of token to item
    mapping(bytes32 => Item) itemsStatus;
    
    // used to check if dag already exists
    mapping(string => bool) itemsExist;
    
    // used to match peerID and account, multiple check to always have latest PeerID in User struct & just one node for identity (split to allow user interchange of peerID/devices)
    mapping(address => User) userFromAdr;
    
    // to map if user voted already to avoid double voting (case 1 : votes user, case 2 : vote item)
    mapping(address => mapping(address => bool)) vote;

    // used to check the state of the token id by owner
    enum State
    {
        none,           // item cant be bought
        forSale,        // item costs a fixed price of coin
        timeAuction,    // item starts from a base and ends in Time
        priceOffering,  // item starts from a low price, any extra is donation
        crowFunded,     // item starts from a low price, , till amount = 0
        timeCrowFunded, // item starts from low price, every new owner increment
        rent,           // item can be used but its paid before the time
        rentForSale     // item can be used but if sold from client, profit
    }
    
    // used to impose type of usages on the platform
    struct License
    {
        bool canEdit;     // an owner can download the file
        bool canBorrow;   // an user can use it as its own
        bool canBeListed; // can be sown in catalogue
        bool isProtected; // is protected by psw
    }
    
    // used to temporary store values then emitted in event
    struct ItemInfo
    {
        string tag;
        string dag;
        string name;
    }
    
    // used to store custom behaviour on belongings
    struct Item
    {
        uint interest;              // based on the passive intrest choose
        License license;            // to check if licenses offered by creator are respected
        State state;                // to store specifics owner state of the item
        bool voted;                 // to check if already voted this item from other user
        uint timeCreation;          // to check oldies
    }
    
    // used to store into mappings repo-related data about addresses, used to link single accs in pubsub, used to mark bad players, display votes left per day, display time before reset, time creation*
    struct User
    {
        string peerID;      // to do relayd-direct connection with peers
        bool banned;        // to default mute/tag/disable vote/ to suckers
        address inventory;  // to store contributions to the platform - smart contract address
        uint level;         // to do calculations on repo
        uint voteLeft;      // to display left votes for the day
        uint voteSpent;     // to valuate player activity
        uint lastVoteCheck; // to evaluate if refilling votes to 100
        uint timeCreation;  //* is used to restrict comments to olders*
    }
    
    // used to get from events a compressed indexed result
    struct Inv
    {
        uint id;
        address inventory;
        address owner;
    }

    
    //////////////
    /// EVENTS ///      // should optimize dagnode to become bytes1[] contentTypes, bytes4[] contentIndices, bytes32[] contentHashes OR USING blake2b-328 to split to split in 32bytesx2
    //////////////
    
    // to read from front end, emitted every transfer
    event ItemBases(
        uint indexed id,               // specific token id
        address indexed inventoryAdr,  // to check balance of specific inventory token
        string indexed mainTag,        // to check based on one tag + 6
        address author,                // to check the creators
        string dagNode,                // the ipfs node ref
        string assetName               // the item name
        );
        
    event ItemUpdates(
        address indexed owner,         // to check the actual owners
        string indexed dagNode,        // the ipfs node ref
        License license,               // rules applied by creator
        uint amount,                   // the balance he owns
        State state,                   // type of buying mechanism
        uint soloIntent                // stores creator perchentage
        );
        
    event ItemVotes(
        Inv indexed inventory,       // to match specifi items belonging to an owner
        address indexed _from,       // to match userBase
        uint indexed repo,           // to index by repo ( display best 1, worst 1, best 2, worst 2 etc)
        bool isPositive,             // to know if disliked or liked
        string dagCid                // to store comments with attachments (additional pic, text)
        );
        
    event ItemGenerated(
        address indexed inventory,
        uint indexed id,
        address indexed from,
        string dagCid
        );
    
    // once per account emit an event used from front end to deduct by logs the needed values (i.e. this address bal, deduce nicknames from addrs, exclude unwanted users)
    event UserBases(
        address indexed account,  // to store unique users
        string indexed nickname,  // to display users
        bool indexed banned,      // to hold blacklist of under 0 repo
        uint timeCreation         // to do 100votes reset
        );
        
    // every tyme an account edits his profile/changes device a function to update essential peerID ref & dagcid to display extras on profiles
    event UserUpdates(
        address indexed account,   // to match userBase
        string indexed peedID,     // to check node status/perform pubsub between accs
        string indexed dagCid      // to store different profiles extras (profile pic, bio) - could be used along with a ipns to store scores?, character dresses?
        );
        
    // every time a vote is being sent by an address it can be deducted by front end from logs checking either sender, recepient, repo (i.e.-0.05 or 0.0003 -> includes strength) amount in comment (dagCid)
    event UserVotes(
        address indexed _from,      // to match userBase
        address indexed _to,        // to match vote to who/what
        uint indexed repo,          // to index by repo ( display best 1, worst 1, best 2, worst 2 etc)
        bool isPositive,            // to know if disliked or liked
        string dagCid               // to store comments with attachments (additional pic, text)
        );
     
     
    ////////////
    // DEPLOY //
    ////////////
        
    constructor(address payable[] memory _units) public validInit(_units)
    {
        vault = address(new SplitPayment(_units));
    }
      
        
    //////////////////////
    // PUBLIC FUNCTIONS // 
    //////////////////////
        
    // used to create an user for account, it checks if peer ID or account already exists, then if not, it creates a new user
    function CreateUser(string memory dagCid, string memory nickname, string memory peerID)
    validUser(false)
    public
    {
        User memory user = User(peerID,false,address(0),1,100,0,now,now);
        userFromAdr[msg.sender] = user; 
        
        emit UserBases(msg.sender, nickname, false, now);
        emit UserUpdates(msg.sender, peerID, dagCid);
    }
    
    // used to update profile picture or peer id, checks if it is a registered user
    function UpdateUser(string memory dagCid, string memory peerID)
    validUser(true)
    public
    {
        userFromAdr[msg.sender].peerID = peerID;
        
        emit UserUpdates(msg.sender, peerID, dagCid);
    }
    
    // used to vote any address belonging to an user, with a strength, positively or negatively, it checks if !banned, !alreadyVoted, !votingOlder, !outOfStrength, peer!=0
    function Vote(address to, address inventory, uint Tokenid, uint strength, bool isPositive, string memory dagCid) 
    validUser(true) 
    validVote(to, Tokenid, inventory, strength)
    public
    {
        Inv memory inv = Inv(Tokenid, inventory, to);
        
        if(Tokenid != 0)
        {
            bytes32 key = keccak256(abi.encodePacked(inventory, Tokenid, to));
            itemsStatus[key].voted = true;
            
            emit ItemVotes(inv, msg.sender, strength/3, isPositive, dagCid);
            emit UserVotes(msg.sender, to, strength/3, isPositive, dagCid);
            emit UserVotes(msg.sender, Inventory(inventory).Author(), strength/3, isPositive, dagCid);
        }
        if(Tokenid == 0)
        {
            vote[msg.sender][to] = true;
            emit UserVotes(msg.sender, to, strength, isPositive, dagCid);
        }
        
        VoteSpent(strength);
    }
    
    // used to edit an already made vote to an user, checks if valid vote, can only edit once a day / sync with lastVoteCheck
    function EditVote(address to, address inventory, uint id, uint strength, bool isPositive, string memory dagCid) 
    validUser(true) 
    validVote(to, id, inventory, strength)
    public
    {
        if(id != 0)
        {
            bytes32 key = keccak256(abi.encodePacked(inventory, id, to));
            Inv memory inv = Inv(id, inventory, to);
            
            require(itemsStatus[key].voted == true, "cant edit vote, not existing. reverting");
            
            emit ItemVotes(inv, msg.sender, strength/3, isPositive, dagCid);
        }
        if (id == 0)
        {
            require(vote[msg.sender][to] == true, "cant edit vote not existing. reverting");
        
            emit UserVotes(msg.sender, to, strength, isPositive, dagCid);
        }
        
        VoteSpent(strength);
    }
    
    // used to check if user can obstain his daily 100 votes
    function TopUpUser()
    validUser(true)
    public 
    {
        User memory user = userFromAdr[msg.sender];
        
        if(now >= user.lastVoteCheck + 86400)
        {
            user.lastVoteCheck = now;
            user.voteLeft = 100;
            
            userFromAdr[msg.sender] = user;
        }
        else
        {
            revert("cant top up user votes. reverting");
        }
    }
    
    // used to generate assets
    function CreateInventory()
    validUser(true) 
    public
    returns(address)
    {
        Inventory instance;
        
        if(userFromAdr[msg.sender].inventory == address(0))
        {
            // initialize inventory
            instance = new Inventory(msg.sender);
            userFromAdr[msg.sender].inventory = address(instance);
            userFromAdr[msg.sender].level += 1;
        }
        else
        {
            // returns existing instance
            instance = Inventory(userFromAdr[msg.sender].inventory);
        }
        
        return address(instance);
    }
    
    // used to deploy erc1155 associated with asset datas ( hard coded 25 votes to create asset )
    function CreateAsset(address inventory, uint assetSupply, bytes memory encodedAssetStatus, bytes memory encodedAssetInfo)
    validUser(true) 
    validInventory(inventory, assetSupply)
    public
    {
        require(userFromAdr[msg.sender].voteLeft >= 25, "ran out of votes to create an asset. reverting");
        VoteSpent(25);

        // converts bytes to structs to check validity
        ItemInfo memory decodedItemInfo = abi.decode(encodedAssetInfo, (ItemInfo));
        CheckDecodedInfo(decodedItemInfo);
        Item memory decodedItemStatus = abi.decode(encodedAssetStatus, (Item));
        
        // sets time of creation
        decodedItemStatus.timeCreation = now;
        
        // sets unique ipfs hash per item
        itemsExist[decodedItemInfo.dag] = true;
        
        // creates the token and sends to creator
        uint id = Inventory(inventory).CreateItem(msg.sender, assetSupply);
        bytes32 key = keccak256(abi.encodePacked(inventory, id, msg.sender));
        itemsStatus[key] = decodedItemStatus;
        
        emit ItemBases(id, inventory, decodedItemInfo.tag, msg.sender, decodedItemInfo.dag, decodedItemInfo.name);
        emit ItemUpdates(msg.sender, decodedItemInfo.dag, decodedItemStatus.license, assetSupply, decodedItemStatus.state, decodedItemStatus.interest);
    }
    
    
    ///////////////
    // MODIFIERS //
    ///////////////
    
    modifier validInit(address payable[] memory units)
    {
        require(units.length == 100, "has to be init with 100 units. reverting");
        _;
    }
    
    modifier validUser(bool registered)
    {
        require(msg.sender != address(0), "invalid address. reverting");
        
        if(registered)
        {
            require(bytes(userFromAdr[msg.sender].peerID).length != 0, "address is not registered. reverting");
        }
        else
        {
            require(bytes(userFromAdr[msg.sender].peerID).length == 0, "user already exists. reverting");
        }
        _;
    }
    
    modifier validVote(address _to, uint id, address inventory, uint strength)
    {
        User memory user = userFromAdr[msg.sender];

        require(strength > 0, "cant vote with 0 strength. reverting");
        require(bytes(user.peerID).length != 0, "user doen't exists. reverting");
        require(user.voteLeft >= strength, "ran out of votes. reverting");
        require(user.banned == false, "repo is below limit. reverting");
        if(id != 0 && inventory != address(0))
        {
            require(Inventory(inventory).balanceOf(_to, id)>0, "either receiver doesnt own token or token doesnt exist. reverting");
            
            bytes32 key = keccak256(abi.encodePacked(inventory, id, _to));
            require(itemsStatus[key].voted == false, "already voted. reverting");
            
            User memory user_author = userFromAdr[Inventory(inventory).Author()];
            require((now - itemsStatus[key].timeCreation) * user_author.voteSpent <= ((now - user.timeCreation) * user.voteSpent), "cant vote olders with more activity. reverting");
        }
        else if(id == 0 && inventory == address(0))
        {
            User memory user_other = userFromAdr[_to];
            require(vote[msg.sender][_to] == false, "can't vote twice. reverting");
            require((now - user_other.timeCreation) * user_other.voteSpent <= ((now - user.timeCreation) * user.voteSpent), "cant vote olders with more activity. reverting"); // *olders mechanism
        }
        else
        {
            revert("can not edit this vote. Reverting");
        }
        _;
    }
    
    modifier validInventory(address inventory, uint supply)
    {
        require(supply>0, "supply cant be 0. reverting");
        require(Inventory(inventory).Author() == msg.sender, "inventory doesnt exists. reverting");
        _;
    }
    
    
    /////////////
    // Helpers //
    /////////////
    
    // helper for front end to check if a user with msg.sender param is valid as registered, doesnt cost gas
    function CheckUser() validUser(true) view public returns(bool)
    {
        return true;
    }
    // helper to check if registered user can topup
    function CheckTopUp() validUser(true) view public returns(bool)
    {
        require(now >= userFromAdr[msg.sender].lastVoteCheck + 86400, "can't top up. reverting");
        return true;
    }
    // helpers for front end check if a vote with these params is valid, doesnt cost gas
    function CheckVote(address to, address inventory, uint Tokenid, uint strength) validVote(to, Tokenid, inventory, strength) view public returns(bool)
    {
        return true;
    }
    // helper to check decoded asset info being right
    function CheckDecodedInfo(ItemInfo memory item) view public 
    {
        uint tag = bytes(item.tag).length;
        uint name = bytes(item.name).length;
        require(tag >= 2 && tag <= 16, "tag length must be between 2 or 16 letters. reverting");
        require(itemsExist[item.dag] == false && bytes(item.dag).length == 34, "the item already exists or length is wrong. reverting");
        require(name >= 3 && name <= 32, "name length must be between 3 or 32 letters. reverting");
    }
    // helpers to get encoded ItemInfo
    function GetEncodedInfo(ItemInfo memory info) pure public returns(bytes memory)
    {
        return abi.encode(info);
    }
    // helpers to get encoded Item
    function GetEncodedStatus(Item memory status) pure public returns(bytes memory)
    {
        return abi.encode(status);
    }
    // helper to determine vault to pay fees
    function Vault() view external returns (address)
    {
        return vault;
    }
    // helper to store updated user votes
    function VoteSpent(uint strength) internal
    {
        User memory user = userFromAdr[msg.sender];
        user.voteLeft -= strength;
        user.voteSpent += strength;
        userFromAdr[msg.sender] = user;
    }
}
