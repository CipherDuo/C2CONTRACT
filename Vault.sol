pragma solidity ^0.6.6;

// interfaces
import "github.com/OpenZeppelin/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/contracts/access/Ownable.sol";
import "https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/interfaces/IUniswapV2Router02.sol";
interface IYDAI {
  function deposit(uint _amount) external;
  function withdraw(uint _amount) external;
  function balanceOf(address _address) external view returns(uint);
  function getPricePerFullShare() external view returns(uint);
}

// contracts
contract Vault is Ownable {
  address internal admin;
  
  IERC20 internal constant dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
  IYDAI internal constant yDai = IYDAI(0xC2cB1040220768554cf699b0d863A3cd4324ce32);
  
  IUniswapV2Router02 internal constant uniswapRouter02 = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  
  constructor() public Ownable() {
    admin = msg.sender;
  }

  function depositETH(uint amount, uint timeOfExpiration) public payable ValidAddress(){
      
    uint deadline = now + timeOfExpiration;
    
    uniswapRouter02.swapETHForExactTokens{value : msg.value}(amount, getPathForETHtoDAI(), address(this), deadline);
    
     _save(dai.balanceOf(address(this)));
    
  }
  
  function depositDAI(uint amount) public ValidAddress() ValidDAIDeposit(amount) {
      
     _save(amount);
  }
  
  function withdrawDAI(uint amount) public onlyOwner() ValidDAIWithdraw(amount)  {
      
    _spend(amount, msg.sender);
  }
  
  function withdrawETH(uint amount, uint timeOfExpiration) public onlyOwner() {
      
    _spend(amount, address(this));
    
    uint deadline = now + timeOfExpiration;
    
    uniswapRouter02.swapExactTokensForETH(amount, amount+1, getPathForDAItoETH(), address(this), deadline);
    
  }
  



  function _spend(uint amount, address recipient) internal onlyOwner {
    uint balanceShares = yDai.balanceOf(address(this));
    yDai.withdraw(balanceShares);
    dai.transfer(recipient, amount);
  }

  function _save(uint amount) internal {
    dai.approve(address(yDai), amount);
    yDai.deposit(amount);
  }

  function balance() external view returns(uint) {
    uint price = yDai.getPricePerFullShare();
    uint balanceShares = yDai.balanceOf(address(this));
    return balanceShares * price;
  }
  
  
  function getEstimatedETHforDAI(uint DAIAmount) public view returns (uint[] memory) {
    return uniswapRouter02.getAmountsIn(DAIAmount, getPathForETHtoDAI());
  }
  
  function getEstimatedDAIforETH(uint ETHAmount) public view returns (uint[] memory) {
    return uniswapRouter02.getAmountsIn(ETHAmount, getPathForDAItoETH());
  }
  
  function getPathForETHtoDAI() internal pure returns (address[] memory) {
    address[] memory path = new address[](2);
    path[0] = uniswapRouter02.WETH();
    path[1] = address(dai);
    
    return path;
  }
  
  function getPathForDAItoETH() internal pure returns (address[] memory) {
    address[] memory path = new address[](2);
    path[1] = address(dai);
    path[0] = uniswapRouter02.WETH();
    
    return path;
  }
  
  
  modifier ValidDAIDeposit(uint amount)
  {
    require(dai.transferFrom(msg.sender, address(this), amount), 'transferFrom failed.');
    require(dai.approve(address(uniswapRouter02), amount), 'approve failed.');
    _;
  }
  modifier ValidDAIWithdraw(uint amount)
  {
    require(dai.balanceOf(address(this)) > amount, 'not enough dai');
    _;
  }
  modifier ValidTimeAmount(uint timeOfExpiration)
  {
      require(timeOfExpiration > 3600, 'time too low');
      _;
  }
  modifier ValidAddress()
  {
      require(msg.sender != address(0), 'invalid address');
      _;
  }
  
  
  
}