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

    event LoadReport(string key, uint256 value);

    function run() external {
        uint256 deployerKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address deployer = vm.addr(deployerKey);

        console.log("[1/5] Starting SingleBlockLoad script...");

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

        console.log("[4/5] Executing batch swaps...");
        uint256 gasBefore = gasleft();
        uint256 successCount = 0;

        for (uint256 i = 0; i < BATCH_COUNT; i++) {
            try router.swapExactTokensForTokens(SWAP_AMOUNT, 0, path, deployer) {
                successCount++;
            } catch {}
            if ((i + 1) % 10 == 0) {
                console.log(string(abi.encodePacked("      Progress: ", vm.toString(i + 1), "/", vm.toString(BATCH_COUNT))));
            }
        }

        uint256 totalGas = gasBefore - gasleft();
        console.log("      Batch swaps completed");

        emit LoadReport("========== Single Block Load Report ==========", 0);
        emit LoadReport("BatchCount", BATCH_COUNT);
        emit LoadReport("SuccessCount", successCount);
        emit LoadReport("TotalGas", totalGas);
        emit LoadReport("AvgGasPerTx", totalGas / BATCH_COUNT);
        emit LoadReport("SuccessRate", (successCount * 100) / BATCH_COUNT);
        emit LoadReport("================================================", 0);

        vm.stopBroadcast();

        console.log("========== Single Block Load Report ==========");
        console.log(string(abi.encodePacked("BatchCount        : ", vm.toString(BATCH_COUNT))));
        console.log(string(abi.encodePacked("SuccessCount      : ", vm.toString(successCount))));
        console.log(string(abi.encodePacked("TotalGas          : ", vm.toString(totalGas))));
        console.log(string(abi.encodePacked("AvgGasPerTx       : ", vm.toString(totalGas / BATCH_COUNT))));
        console.log(string(abi.encodePacked("SuccessRate       : ", vm.toString((successCount * 100) / BATCH_COUNT), "%")));
        console.log("================================================");
    }
}