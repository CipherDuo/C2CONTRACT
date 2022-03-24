pragma solidity ^0.6.2;
pragma experimental ABIEncoderV2;

import "github:OpenZeppelin/openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import "github:OpenZeppelin/openzeppelin-contracts/contracts/token/ERC1155/IERC1155Receiver.sol";
import "github:OpenZeppelin/openzeppelin-contracts/contracts/introspection/ERC165.sol";
import "github:OpenZeppelin/openzeppelin-contracts/contracts/access/Ownable.sol";
import "github:OpenZeppelin/openzeppelin-contracts/contracts/math/SafeMath.sol";
import "github:OpenZeppelin/openzeppelin-contracts/contracts/utils/Address.sol";
import "github:OpenZeppelin/openzeppelin-contracts/contracts/utils/Counters.sol";

contract Inventory is ERC165, IERC1155, Ownable
{
    using SafeMath for uint256;
    using Address for address;
    using Counters for Counters.Counter;
    Counters.Counter private _ItemIds;
    
    address private author;

    mapping (uint256 => mapping(address => uint256)) private _balances;

    mapping (address => mapping(address => bool)) private _operatorApprovals;

    bytes4 private constant _INTERFACE_ID_ERC1155 = 0xd9b67a26;

    constructor(address _author) Ownable() public {
        _registerInterface(_INTERFACE_ID_ERC1155);
        author = _author;
    }

    function balanceOf(address account, uint256 id) public view override returns (uint256) {
        require(account != address(0), "ERC1155: balance query for the zero address");
        return _balances[id][account];
    }

    function balanceOfBatch(
        address[] memory accounts,
        uint256[] memory ids
    )
        public
        view
        override
        returns (uint256[] memory)
    {
        require(accounts.length == ids.length, "ERC1155: accounts and IDs must have same lengths");

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            require(accounts[i] != address(0), "ERC1155: some address in batch balance query is zero");
            batchBalances[i] = _balances[ids[i]][accounts[i]];
        }

        return batchBalances;
    }

    function setApprovalForAll(address operator, bool approved) onlyOwner external override virtual {
        require(msg.sender != operator, "ERC1155: cannot set approval status for self");
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }
    
    function isApprovedForAll(address account, address operator) public view override returns (bool) {
        return _operatorApprovals[account][operator];
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 value,
        bytes calldata data
    )
        onlyOwner
        external
        override
        virtual
    {
        require(to != address(0), "ERC1155: target address must be non-zero");
        require(
            from == msg.sender || isApprovedForAll(from, msg.sender) == true,
            "ERC1155: need operator approval for 3rd party transfers"
        );

        _balances[id][from] = _balances[id][from].sub(value, "ERC1155: insufficient balance for transfer");
        _balances[id][to] = _balances[id][to].add(value);

        emit TransferSingle(msg.sender, from, to, id, value);

        _doSafeTransferAcceptanceCheck(msg.sender, from, to, id, value, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    )
        onlyOwner
        external
        override
        virtual
    {
        require(ids.length == values.length, "ERC1155: IDs and values must have same lengths");
        require(to != address(0), "ERC1155: target address must be non-zero");
        require(
            from == msg.sender || isApprovedForAll(from, msg.sender) == true,
            "ERC1155: need operator approval for 3rd party transfers"
        );

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 value = values[i];

            _balances[id][from] = _balances[id][from].sub(
                value,
                "ERC1155: insufficient balance of some token type for transfer"
            );
            _balances[id][to] = _balances[id][to].add(value);
        }

        emit TransferBatch(msg.sender, from, to, ids, values);

        _doSafeBatchTransferAcceptanceCheck(msg.sender, from, to, ids, values, data);
    }
    
    function CreateItem(address receiver, uint assetAmount) onlyOwner external returns(uint)
    {
        _ItemIds.increment();
        uint id = _ItemIds.current();
        
        _mint(receiver, id, assetAmount, ""); 
        return id;
    }
    
    function CreateGen(address receiver) onlyOwner external returns(uint)
    {
        _ItemIds.increment();
        uint id = _ItemIds.current();
        
        _mint(receiver, id, 1, ""); 
        return id;
    }
    
    function Author() onlyOwner external view returns(address)
    {
        return author;
    }

    function _mint(address to, uint256 id, uint256 value, bytes memory data) internal virtual {
        require(to != address(0), "ERC1155: mint to the zero address");

        _balances[id][to] = _balances[id][to].add(value);
        emit TransferSingle(msg.sender, address(0), to, id, value);

        _doSafeTransferAcceptanceCheck(msg.sender, address(0), to, id, value, data);
    }

    function _mintBatch(address to, uint256[] memory ids, uint256[] memory values, bytes memory data) internal virtual {
        require(to != address(0), "ERC1155: batch mint to the zero address");
        require(ids.length == values.length, "ERC1155: minted IDs and values must have same lengths");

        for(uint i = 0; i < ids.length; i++) {
            _balances[ids[i]][to] = values[i].add(_balances[ids[i]][to]);
        }

        emit TransferBatch(msg.sender, address(0), to, ids, values);

        _doSafeBatchTransferAcceptanceCheck(msg.sender, address(0), to, ids, values, data);
    }

    function _burn(address account, uint256 id, uint256 value) internal virtual {
        require(account != address(0), "ERC1155: attempting to burn tokens on zero account");

        _balances[id][account] = _balances[id][account].sub(
            value,
            "ERC1155: attempting to burn more than balance"
        );
        emit TransferSingle(msg.sender, account, address(0), id, value);
    }

    function _burnBatch(address account, uint256[] memory ids, uint256[] memory values) internal virtual {
        require(account != address(0), "ERC1155: attempting to burn batch of tokens on zero account");
        require(ids.length == values.length, "ERC1155: burnt IDs and values must have same lengths");

        for(uint i = 0; i < ids.length; i++) {
            _balances[ids[i]][account] = _balances[ids[i]][account].sub(
                values[i],
                "ERC1155: attempting to burn more than balance for some token"
            );
        }

        emit TransferBatch(msg.sender, account, address(0), ids, values);
    }

    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 value,
        bytes memory data
    )
        internal
        virtual
    {
        if(to.isContract()) {
            require(
                IERC1155Receiver(to).onERC1155Received(operator, from, id, value, data) ==
                    IERC1155Receiver(to).onERC1155Received.selector,
                "ERC1155: got unknown value from onERC1155Received"
            );
        }
    }

    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    )
        internal
        virtual
    {
        if(to.isContract()) {
            require(
                IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, values, data) ==
                    IERC1155Receiver(to).onERC1155BatchReceived.selector,
                "ERC1155: got unknown value from onERC1155BatchReceived"
            );
        }
    }
}
