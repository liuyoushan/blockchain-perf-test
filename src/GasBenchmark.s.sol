// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "contracts/MiniSwapRouter.sol";
import "contracts/MiniSwapFactory.sol";
import "contracts/MiniSwapPair.sol";
import "contracts/MyERC20.sol";

contract GasBenchmark is Script {
    uint256 constant INITIAL_MINT = 10000 ether;
    uint256 constant LIQUIDITY_AMOUNT = 1000 ether;
    uint256 constant SWAP_AMOUNT = 100 ether;
    uint256 constant APPROVAL_AMOUNT = type(uint256).max - 1;

    function run() external {
        uint256 deployerKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address deployer = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);
        
        MyERC20 tokenA = new MyERC20("TokenA", "TKA");
        MyERC20 tokenB = new MyERC20("TokenB", "TKB");
        MiniSwapFactory factory = new MiniSwapFactory();
        MiniSwapRouter router = new MiniSwapRouter(address(factory));

        tokenA.mint(deployer, INITIAL_MINT);
        tokenB.mint(deployer, INITIAL_MINT);
        tokenA.approve(address(router), APPROVAL_AMOUNT);
        tokenB.approve(address(router), APPROVAL_AMOUNT);

        uint256 gasBefore = gasleft();
        router.addLiquidity(address(tokenA), address(tokenB), LIQUIDITY_AMOUNT, LIQUIDITY_AMOUNT, deployer);
        uint256 gasAddLiquidity = gasBefore - gasleft();

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        gasBefore = gasleft();
        router.swapExactTokensForTokens(SWAP_AMOUNT, 0, path, deployer);
        uint256 gasSwap = gasBefore - gasleft();

        address pairAddr = factory.getPair(address(tokenA), address(tokenB));
        MiniSwapPair pair = MiniSwapPair(pairAddr);
        uint256 lpBalance = pair.balanceOf(deployer);
        pair.approve(address(router), lpBalance);

        gasBefore = gasleft();
        router.removeLiquidity(address(tokenA), address(tokenB), lpBalance, deployer);
        uint256 gasRemoveLiquidity = gasBefore - gasleft();

        vm.stopBroadcast();

        console.log("========== Gas Benchmark Report ==========");
        console.log("addLiquidity      :", gasAddLiquidity);
        console.log("swap              :", gasSwap);
        console.log("removeLiquidity   :", gasRemoveLiquidity);
        console.log("==========================================");
    }
}