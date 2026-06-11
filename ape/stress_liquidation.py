#!/usr/bin/env python3
"""
清算业务压测脚本（框架）
输出 JSON 报告到 reports/python/ 目录
"""

import json
import time
import threading
import os
from datetime import datetime
from web3 import Web3

# 配置参数
CONCURRENT_USERS = 10
REPORT_DIR = "../reports/python"
RPC_URL = "http://127.0.0.1:8545"
# 长时压测开关：True=循环持续跑；False=只跑一轮基准
LONG_RUN_STRESS = True
LOOP_INTERVAL = 2  # 每轮压测间隔秒

# Anvil 默认测试账户私钥
ANVIL_ACCOUNTS = [
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
    "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d",
    "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a",
    "0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6",
    "0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a",
    "0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba",
    "0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b608d2728",
    "0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356",
    "0xdbda1821b80551c9d65939329250298aa3472ba22feea921c0cf5d0200c9f978",
    "0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6",
]

def single_round_test():
    """单轮压测逻辑，抽离出来支持循环长时跑"""
    # 连接本地网络
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    
    if not w3.is_connected():
        print("❌ 无法连接到本地节点")
        return 0
    
    # 测试账户
    deployer = w3.eth.account.from_key(ANVIL_ACCOUNTS[0])
    
    # 准备测试用户
    users = []
    for i in range(1, min(CONCURRENT_USERS + 1, len(ANVIL_ACCOUNTS))):
        users.append(w3.eth.account.from_key(ANVIL_ACCOUNTS[i]))

    results = []
    errors = []
    start_time = time.time()

    def user_liquidation(user):
        nonlocal results, errors
        try:
            tx_start = time.time()
            # 模拟清算操作（发送一笔空交易作为占位）
            tx_hash = w3.eth.send_transaction({
                "from": user.address,
                "to": deployer.address,
                "value": 0,
                "data": "0x"
            })
            tx_receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
            tx_time = time.time() - tx_start
            
            results.append({
                "user": user.address,
                "tx_hash": tx_hash.hex(),
                "gas_used": int(tx_receipt.gasUsed),
                "time_ms": tx_time * 1000
            })
        except Exception as e:
            errors.append({
                "user": user.address,
                "error": str(e)
            })

    # 并发执行
    threads = []
    for user in users:
        t = threading.Thread(target=user_liquidation, args=(user,))
        threads.append(t)
        t.start()
    for t in threads:
        t.join()

    total_time = time.time() - start_time
    total_tx = len(results) + len(errors)
    tps = len(results) / total_time if total_time > 0 else 0

    # 生成单轮JSON报告
    report = {
        "timestamp": datetime.now().isoformat(),
        "test_name": "Liquidation Stress Test",
        "config": {"concurrent_users": len(users), "network": RPC_URL},
        "results": {
            "total_txs": total_tx,
            "success_txs": len(results),
            "failed_txs": len(errors),
            "success_rate": len(results)/total_tx*100 if total_tx else 0,
            "total_time_ms": total_time*1000,
            "avg_time_ms": sum(r["time_ms"] for r in results)/len(results) if results else 0,
            "avg_gas_used": sum(r["gas_used"] for r in results)/len(results) if results else 0,
            "throughput_tps": tps
        },
        "detailed_results": results,
        "errors": errors
    }
    os.makedirs(REPORT_DIR, exist_ok=True)
    report_filename = f"{REPORT_DIR}/stress_liquidation_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    with open(report_filename, "w") as f:
        json.dump(report, f, indent=2)

    # 控制台输出
    print(f"\n【本轮清算压测完成】TPS: {tps:.2f} | 成功率: {report['results']['success_rate']:.2f}%")
    return tps

def run_liquidation_stress_test():
    if LONG_RUN_STRESS:
        # 长时循环压测，进程常驻，持续产出指标
        print("🔄 开启长时稳定性压测，持续循环发送交易... Ctrl+C 停止")
        while True:
            single_round_test()
            time.sleep(LOOP_INTERVAL)
    else:
        # 短时基准压测，仅执行一轮后退出
        single_round_test()
        print("✅ 单轮基准压测执行完成，程序退出")

def main():
    try:
        run_liquidation_stress_test()
    except KeyboardInterrupt:
        print("\n🛑 压测程序手动终止")

if __name__ == "__main__":
    main()