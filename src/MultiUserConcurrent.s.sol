// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "contracts/MiniSwapRouter.sol";
import "contracts/MiniSwapFactory.sol";
import "contracts/MyERC20.sol";

contract MultiUserConcurrent is Script {
    uint256 public constant USER_NUM = 5;
    uint256 public constant SWAP_AMOUNT = 1 ether;
    uint256 constant APPROVAL_AMOUNT = type(uint256).max - 1;

    event Report(string key, uint256 value);

    function run() external {
        uint256 deployerKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address deployer = vm.addr(deployerKey);

        console.log("[1/5] Starting MultiUserConcurrent script...");

        vm.startBroadcast(deployerKey);
        
        console.log("[2/5] Deploying contracts...");
        MyERC20 tokenA = new MyERC20("TokenA", "TKA");
        MyERC20 tokenB = new MyERC20("TokenB", "TKB");
        MiniSwapFactory factory = new MiniSwapFactory();
        MiniSwapRouter router = new MiniSwapRouter(address(factory));
        console.log("      Contracts deployed");

        console.log("[3/5] Minting tokens and adding liquidity...");
        tokenA.mint(deployer, 100000 ether);
        tokenB.mint(deployer, 100000 ether);
        tokenA.approve(address(router), APPROVAL_AMOUNT);
        tokenB.approve(address(router), APPROVAL_AMOUNT);
        router.addLiquidity(address(tokenA), address(tokenB), 50000 ether, 50000 ether, deployer);
        console.log("      Liquidity added");

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        console.log("[4/5] Executing concurrent user swaps...");
        uint256 successCount = 0;
        uint256 gasTotal = gasleft();

        for (uint256 i = 0; i < USER_NUM; i++) {
            console.log(string(abi.encodePacked("      User ", vm.toString(i + 1), "/", vm.toString(USER_NUM), " swapping...")));
            try router.swapExactTokensForTokens(SWAP_AMOUNT, 0, path, deployer) {
                successCount++;
            } catch {}
        }
        gasTotal = gasTotal - gasleft();
        console.log("      All user swaps completed");

        // 使用事件输出报告（在广播内）
        emit Report("========== Multi User Concurrent Report ==========", 0);
        emit Report("UserCount", USER_NUM);
        emit Report("SuccessCount", successCount);
        emit Report("TotalGas", gasTotal);
        emit Report("AvgGas", gasTotal / USER_NUM);
        emit Report("SuccessRate", (successCount * 100) / USER_NUM);
        emit Report("====================================================", 0);

        vm.stopBroadcast();

        console.log("========== Multi User Concurrent Report ==========");
        console.log(string(abi.encodePacked("UserCount         : ", vm.toString(USER_NUM))));
        console.log(string(abi.encodePacked("SuccessCount      : ", vm.toString(successCount))));
        console.log(string(abi.encodePacked("TotalGas          : ", vm.toString(gasTotal))));
        console.log(string(abi.encodePacked("AvgGas            : ", vm.toString(gasTotal / USER_NUM))));
        console.log(string(abi.encodePacked("SuccessRate       : ", vm.toString((successCount * 100) / USER_NUM), "%")));
        console.log("====================================================");
    }
}