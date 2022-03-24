pragma solidity ^0.6.2;
pragma experimental ABIEncoderV2;

import "github:OpenZeppelin/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "github:OpenZeppelin/openzeppelin-contracts/contracts/GSN/Context.sol";
import "github:OpenZeppelin/openzeppelin-contracts/contracts/access/Ownable.sol";
import "./Uniswap/IUniswapRouter.sol";
import "./Uniswap/IUniswapPair.sol";
import "./Uniswap/IUniswapFactory.sol";
import "./SplitPayment.sol";
import "./Factory.sol";

// currency in game
contract Coin is ERC20, Ownable
{
    IUniswapRouter uniswapRouter;
    IUniswapPair uniswapPair;
    IUniswapFactory uniswapFactory;
    
    constructor() ERC20("cypherDuo_Coin", "C2C") Ownable() public {
    
        uniswapFactory = IUniswapFactory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
        uniswapRouter = IUniswapRouter(0xf164fC0Ec4E93095b804a4795bBe1e041497b92a);
        
    }
    
    function init() external onlyOwner payable
    {
        uniswapPair = IUniswapPair(msg.sender, address(this)));
    }
    
    // function to mint token based on value uniswap for buyer + invest eth + same amount in uniswap      
    function invest(address buyer) external onlyOwner payable
    {
        (uint reserve0, uint reserve1,) = uniswapPair.getReserves();
        uint amount = uniswapRouter.quote(msg.value, reserve0, reserve1);
        
        // mints the 50% secure vault found
        address payable[] memory dist = SplitPayment(Factory(owner()).Vault()).unitsGet();
        uint count = dist.length;
        for(uint i = 0; i<count; i++)
        {
            dist[i].transfer(msg.value/count);
            _mint(dist[i], amount/count);
        }
        
        _mint(buyer, amount);
    }
    
    function buy(address buyer) external onlyOwner payable
    {
        (uint reserve0, uint reserve1,) = uniswapPair.getReserves();
        uint amount = uniswapRouter.quote(msg.value, reserve0, reserve1);
        
        address weth = uniswapRouter.WETH();
        address[] memory path;
        path[0] = weth;
        path[1] = address(this);

        uniswapRouter.swapETHForExactTokens(amount, path, buyer, 120);
    }
}