// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "contracts/MiniSwapFactory.sol";
import "contracts/MiniSwapRouter.sol";
import "contracts/MiniSwapPair.sol";
import "contracts/MyERC20.sol";


contract GasReportTest is Test {
    MyERC20 public tokenA;
    MyERC20 public tokenB;
    MiniSwapFactory public factory;
    MiniSwapRouter public router;
    MiniSwapPair public pair;

    address public deployer = address(0x1234);
    uint256 public constant INITIAL_MINT = 10000 ether;
    uint256 public constant LIQUIDITY_AMOUNT = 1000 ether;
    uint256 public constant SWAP_AMOUNT = 100 ether;

    function setUp() public {
        vm.deal(deployer, 100 ether);
        
        vm.startPrank(deployer);
        tokenA = new MyERC20("TokenA", "TKA");
        tokenB = new MyERC20("TokenB", "TKB");
        factory = new MiniSwapFactory();
        router = new MiniSwapRouter(address(factory));
        
        tokenA.mint(deployer, INITIAL_MINT);
        tokenB.mint(deployer, INITIAL_MINT);
        
        tokenA.approve(address(router), type(uint256).max - 1);
        tokenB.approve(address(router), type(uint256).max - 1);
        
        router.addLiquidity(address(tokenA), address(tokenB), LIQUIDITY_AMOUNT, LIQUIDITY_AMOUNT, deployer);
        
        pair = MiniSwapPair(factory.getPair(address(tokenA), address(tokenB)));
        vm.stopPrank();
    }

    function test_gas_swap() public {
        vm.startPrank(deployer);
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        router.swapExactTokensForTokens(SWAP_AMOUNT, 0, path, deployer);
        vm.stopPrank();
    }

    function test_gas_addLiquidity() public {
        vm.startPrank(deployer);
        tokenA.mint(deployer, 100 ether);
        tokenB.mint(deployer, 100 ether);
        router.addLiquidity(address(tokenA), address(tokenB), 50 ether, 50 ether, deployer);
        vm.stopPrank();
    }

    function test_gas_removeLiquidity() public {
        vm.startPrank(deployer);
        uint256 lpBalance = pair.balanceOf(deployer);
        pair.approve(address(router), lpBalance);
        router.removeLiquidity(address(tokenA), address(tokenB), lpBalance, deployer);
        vm.stopPrank();
    }

    function test_gas_mint() public {
        vm.startPrank(deployer);
        tokenA.mint(deployer, 1000 ether);
        vm.stopPrank();
    }

    function test_gas_transfer() public {
        vm.startPrank(deployer);
        tokenA.transfer(address(0x5678), 100 ether);
        vm.stopPrank();
    }

    function test_gas_approve() public {
        vm.startPrank(deployer);
        tokenA.approve(address(router), type(uint256).max - 1);
        vm.stopPrank();
    }

    function test_gas_createPair() public {
        vm.startPrank(deployer);
        MyERC20 tokenC = new MyERC20("TokenC", "TKC");
        MyERC20 tokenD = new MyERC20("TokenD", "TKD");
        factory.createPair(address(tokenC), address(tokenD));
        vm.stopPrank();
    }
}
