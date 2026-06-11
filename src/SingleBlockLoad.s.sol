// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "contracts/MiniSwapRouter.sol";
import "contracts/MiniSwapFactory.sol";
import "contracts/MyERC20.sol";

contract SingleBlockLoad is Script {
    uint256 public constant BATCH_COUNT = 50;
    uint256 public constant SWAP_AMOUNT = 1 ether;
    uint256 constant APPROVAL_AMOUNT = type(uint256).max - 1;

    function run() external {
        uint256 deployerKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address deployer = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);
        
        MyERC20 tokenA = new MyERC20("TokenA", "TKA");
        MyERC20 tokenB = new MyERC20("TokenB", "TKB");
        MiniSwapFactory factory = new MiniSwapFactory();
        MiniSwapRouter router = new MiniSwapRouter(address(factory));

        tokenA.mint(deployer, 100000 ether);
        tokenB.mint(deployer, 100000 ether);
        tokenA.approve(address(router), APPROVAL_AMOUNT);
        tokenB.approve(address(router), APPROVAL_AMOUNT);
        router.addLiquidity(address(tokenA), address(tokenB), 50000 ether, 50000 ether, deployer);

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        uint256 gasBefore = gasleft();
        uint256 successCount = 0;

        for (uint256 i = 0; i < BATCH_COUNT; i++) {
            try router.swapExactTokensForTokens(SWAP_AMOUNT, 0, path, deployer) {
                successCount++;
            } catch {}
        }

        uint256 totalGas = gasBefore - gasleft();
        vm.stopBroadcast();

        console.log("========== Single Block Load Report ==========");
        console.log("Batch count       :", BATCH_COUNT);
        console.log("Success count     :", successCount);
        console.log("Total gas used    :", totalGas);
        console.log("Avg gas per tx    :", totalGas / BATCH_COUNT);
        console.log("Success rate      :", (successCount * 100) / BATCH_COUNT, "%");
        console.log("================================================");
    }
}