#!/usr/bin/env python3
"""
DEX Swap 并发压测脚本
输出 JSON 报告到 perf/reports/ 目录
"""

import json
import time
import threading
from datetime import datetime

from ape import accounts, project, networks

# 配置参数
CONCURRENT_USERS = 10
SWAP_AMOUNT = 10**18
REPORT_DIR = "../reports"

def run_stress_test():
    # 连接本地网络
    with networks.parse_network_choice("ethereum:local:node"):
        # 部署合约
        deployer = accounts.test_accounts[0]
        token_a = project.MyERC20.deploy("TokenA", "TKA", sender=deployer)
        token_b = project.MyERC20.deploy("TokenB", "TKB", sender=deployer)
        factory = project.MiniSwapFactory.deploy(sender=deployer)
        router = project.MiniSwapRouter.deploy(factory.address, sender=deployer)

        # 铸造代币并添加流动性
        token_a.mint(deployer, 100000 * 10**18, sender=deployer)
        token_b.mint(deployer, 100000 * 10**18, sender=deployer)
        token_a.approve(router.address, 2**256 - 1, sender=deployer)
        token_b.approve(router.address, 2**256 - 1, sender=deployer)
        router.addLiquidity(
            token_a.address,
            token_b.address,
            50000 * 10**18,
            50000 * 10**18,
            deployer,
            sender=deployer
        )

        # 准备测试用户
        users = accounts.test_accounts[1:CONCURRENT_USERS + 1]
        for user in users:
            token_a.mint(user, 1000 * 10**18, sender=deployer)
            token_a.approve(router.address, 2**256 - 1, sender=user)

        # 压测执行
        results = []
        errors = []
        start_time = time.time()

        def user_swap(user):
            nonlocal results, errors
            try:
                tx_start = time.time()
                receipt = router.swapExactTokensForTokens(
                    SWAP_AMOUNT,
                    0,
                    [token_a.address, token_b.address],
                    user,
                    sender=user
                )
                tx_time = time.time() - tx_start
                results.append({
                    "user": str(user),
                    "tx_hash": str(receipt.txn_hash),
                    "gas_used": receipt.gas_used,
                    "time_ms": tx_time * 1000
                })
            except Exception as e:
                errors.append({
                    "user": str(user),
                    "error": str(e)
                })

        # 多线程并发执行
        threads = []
        for user in users:
            t = threading.Thread(target=user_swap, args=(user,))
            threads.append(t)
            t.start()

        for t in threads:
            t.join()

        total_time = time.time() - start_time

        # 生成报告
        report = {
            "timestamp": datetime.now().isoformat(),
            "test_name": "DEX Swap Stress Test",
            "config": {
                "concurrent_users": CONCURRENT_USERS,
                "swap_amount": SWAP_AMOUNT,
                "network": "local"
            },
            "results": {
                "total_txs": len(results) + len(errors),
                "success_txs": len(results),
                "failed_txs": len(errors),
                "success_rate": len(results) / (len(results) + len(errors)) * 100,
                "total_time_ms": total_time * 1000,
                "avg_time_ms": sum(r["time_ms"] for r in results) / len(results) if results else 0,
                "avg_gas_used": sum(r["gas_used"] for r in results) / len(results) if results else 0,
                "throughput_tps": len(results) / total_time
            },
            "detailed_results": results,
            "errors": errors
        }

        # 保存报告
        import os
        os.makedirs(REPORT_DIR, exist_ok=True)
        report_filename = f"{REPORT_DIR}/stress_dex_swap_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(report_filename, "w") as f:
            json.dump(report, f, indent=2)

        print(f"\n========== DEX Swap Stress Test Report ==========")
        print(f"Total transactions: {report['results']['total_txs']}")
        print(f"Success rate: {report['results']['success_rate']:.2f}%")
        print(f"Total time: {report['results']['total_time_ms']:.2f} ms")
        print(f"Average time per tx: {report['results']['avg_time_ms']:.2f} ms")
        print(f"Average gas used: {report['results']['avg_gas_used']}")
        print(f"Throughput: {report['results']['throughput_tps']:.2f} TPS")
        print(f"Report saved to: {report_filename}")
        print("==================================================")

def main():
    run_stress_test()

if __name__ == "__main__":
    main()
