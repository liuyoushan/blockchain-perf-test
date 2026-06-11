#!/usr/bin/env python3
"""
DEX Swap 并发压测脚本
输出 JSON 报告到 reports/python/ 目录
"""

import json
import time
import threading
import os
import subprocess
from datetime import datetime
from web3 import Web3

# 配置参数
CONCURRENT_USERS = 10
SWAP_AMOUNT = 10**18
# 使用绝对路径确保无论从哪个目录运行都能找到
REPORT_DIR = "/home/liuyoushan/blockchain-perf-test/reports/python"
RPC_URL = "http://127.0.0.1:8545"

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

def compile_contracts():
    """确保合约已编译"""
    build_dir = os.path.join(os.path.dirname(__file__), "..", "build", "out")
    if not os.path.exists(build_dir):
        print("📦 正在编译合约...")
        subprocess.run(
            ["forge", "build"],
            cwd=os.path.dirname(__file__) + "/..",
            check=True,
            capture_output=True
        )
        print("✅ 合约编译完成")

def run_stress_test():
    # 确保合约已编译
    compile_contracts()
    
    # 连接本地网络
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    assert w3.is_connected(), "无法连接到本地节点"
    
    # 测试账户
    deployer = w3.eth.account.from_key(ANVIL_ACCOUNTS[0])
    
    # 读取编译后的合约
    def load_contract(contract_name):
        contract_path = os.path.join(os.path.dirname(__file__), "..", "build", "out", f"{contract_name}.sol", f"{contract_name}.json")
        with open(contract_path) as f:
            data = json.load(f)
        return data["abi"], data["bytecode"]["object"]
    
    # 加载合约
    myerc20_abi, myerc20_bytecode = load_contract("MyERC20")
    factory_abi, factory_bytecode = load_contract("MiniSwapFactory")
    router_abi, router_bytecode = load_contract("MiniSwapRouter")
    
    # 部署合约
    print("🚀 部署合约...")
    
    # 部署 TokenA
    token_a_contract = w3.eth.contract(abi=myerc20_abi, bytecode=myerc20_bytecode)
    tx = token_a_contract.constructor("TokenA", "TKA").build_transaction({
        "from": deployer.address,
        "nonce": w3.eth.get_transaction_count(deployer.address),
        "gas": 2000000,
        "gasPrice": w3.eth.gas_price
    })
    signed_tx = w3.eth.account.sign_transaction(tx, ANVIL_ACCOUNTS[0])
    tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)
    tx_receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    token_a = w3.eth.contract(address=tx_receipt.contractAddress, abi=myerc20_abi)
    print(f"  TokenA: {token_a.address}")
    
    # 部署 TokenB
    token_b_contract = w3.eth.contract(abi=myerc20_abi, bytecode=myerc20_bytecode)
    tx = token_b_contract.constructor("TokenB", "TKB").build_transaction({
        "from": deployer.address,
        "nonce": w3.eth.get_transaction_count(deployer.address),
        "gas": 2000000,
        "gasPrice": w3.eth.gas_price
    })
    signed_tx = w3.eth.account.sign_transaction(tx, ANVIL_ACCOUNTS[0])
    tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)
    tx_receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    token_b = w3.eth.contract(address=tx_receipt.contractAddress, abi=myerc20_abi)
    print(f"  TokenB: {token_b.address}")
    
    # 部署 Factory
    factory_contract = w3.eth.contract(abi=factory_abi, bytecode=factory_bytecode)
    tx = factory_contract.constructor().build_transaction({
        "from": deployer.address,
        "nonce": w3.eth.get_transaction_count(deployer.address),
        "gas": 3000000,
        "gasPrice": w3.eth.gas_price
    })
    signed_tx = w3.eth.account.sign_transaction(tx, ANVIL_ACCOUNTS[0])
    tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)
    tx_receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    print(f"  Factory tx: {tx_hash.hex()}, status: {tx_receipt.status}")
    if not tx_receipt.contractAddress:
        raise Exception(f"Factory deployment failed. tx: {tx_hash.hex()}, status: {tx_receipt.status}")
    factory_address = tx_receipt.contractAddress
    factory = w3.eth.contract(address=factory_address, abi=factory_abi)
    print(f"  Factory: {factory.address}")
    
    # 部署 Router
    router_contract = w3.eth.contract(abi=router_abi, bytecode=router_bytecode)
    tx = router_contract.constructor(factory.address).build_transaction({
        "from": deployer.address,
        "nonce": w3.eth.get_transaction_count(deployer.address),
        "gas": 2000000,
        "gasPrice": w3.eth.gas_price
    })
    signed_tx = w3.eth.account.sign_transaction(tx, ANVIL_ACCOUNTS[0])
    tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)
    tx_receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    router = w3.eth.contract(address=tx_receipt.contractAddress, abi=router_abi)
    print(f"  Router: {router.address}")
    
    # 铸造代币并添加流动性
    print("💧 铸造代币并添加流动性...")
    
    # 铸造代币
    tx = token_a.functions.mint(deployer.address, 100000 * 10**18).build_transaction({
        "from": deployer.address,
        "nonce": w3.eth.get_transaction_count(deployer.address),
        "gas": 200000,
        "gasPrice": w3.eth.gas_price
    })
    signed_tx = w3.eth.account.sign_transaction(tx, ANVIL_ACCOUNTS[0])
    w3.eth.send_raw_transaction(signed_tx.raw_transaction)
    w3.eth.wait_for_transaction_receipt(signed_tx.hash)
    
    tx = token_b.functions.mint(deployer.address, 100000 * 10**18).build_transaction({
        "from": deployer.address,
        "nonce": w3.eth.get_transaction_count(deployer.address),
        "gas": 200000,
        "gasPrice": w3.eth.gas_price
    })
    signed_tx = w3.eth.account.sign_transaction(tx, ANVIL_ACCOUNTS[0])
    w3.eth.send_raw_transaction(signed_tx.raw_transaction)
    w3.eth.wait_for_transaction_receipt(signed_tx.hash)
    
    # 授权 Router (MyERC20 不允许无限授权，使用 max-1)
    max_uint = 2**256 - 2
    tx = token_a.functions.approve(router.address, max_uint).build_transaction({
        "from": deployer.address,
        "nonce": w3.eth.get_transaction_count(deployer.address),
        "gas": 100000,
        "gasPrice": w3.eth.gas_price
    })
    signed_tx = w3.eth.account.sign_transaction(tx, ANVIL_ACCOUNTS[0])
    w3.eth.send_raw_transaction(signed_tx.raw_transaction)
    w3.eth.wait_for_transaction_receipt(signed_tx.hash)
    
    tx = token_b.functions.approve(router.address, max_uint).build_transaction({
        "from": deployer.address,
        "nonce": w3.eth.get_transaction_count(deployer.address),
        "gas": 100000,
        "gasPrice": w3.eth.gas_price
    })
    signed_tx = w3.eth.account.sign_transaction(tx, ANVIL_ACCOUNTS[0])
    w3.eth.send_raw_transaction(signed_tx.raw_transaction)
    w3.eth.wait_for_transaction_receipt(signed_tx.hash)
    
    # 添加流动性
    tx = router.functions.addLiquidity(
        token_a.address,
        token_b.address,
        50000 * 10**18,
        50000 * 10**18,
        deployer.address
    ).build_transaction({
        "from": deployer.address,
        "nonce": w3.eth.get_transaction_count(deployer.address),
        "gas": 500000,
        "gasPrice": w3.eth.gas_price
    })
    signed_tx = w3.eth.account.sign_transaction(tx, ANVIL_ACCOUNTS[0])
    w3.eth.send_raw_transaction(signed_tx.raw_transaction)
    w3.eth.wait_for_transaction_receipt(signed_tx.hash)
    print("  流动性添加完成")
    
    # 准备测试用户
    print(f"🔄 准备 {CONCURRENT_USERS} 个测试用户...")
    users = []
    for i in range(1, min(CONCURRENT_USERS + 1, len(ANVIL_ACCOUNTS))):
        user_key = ANVIL_ACCOUNTS[i]
        user = w3.eth.account.from_key(user_key)
        users.append({"account": user, "key": user_key})
        # 给用户转 ETH 用于支付 gas
        if w3.eth.get_balance(user.address) < 10**18:
            tx = {
                "from": deployer.address,
                "to": user.address,
                "value": 10**18,
                "nonce": w3.eth.get_transaction_count(deployer.address),
                "gas": 21000,
                "gasPrice": w3.eth.gas_price
            }
            signed_tx = w3.eth.account.sign_transaction(tx, ANVIL_ACCOUNTS[0])
            w3.eth.send_raw_transaction(signed_tx.raw_transaction)
            w3.eth.wait_for_transaction_receipt(signed_tx.hash)
        # 给用户铸造代币
        tx = token_a.functions.mint(user.address, 1000 * 10**18).build_transaction({
            "from": deployer.address,
            "nonce": w3.eth.get_transaction_count(deployer.address),
            "gas": 200000,
            "gasPrice": w3.eth.gas_price
        })
        signed_tx = w3.eth.account.sign_transaction(tx, ANVIL_ACCOUNTS[0])
        w3.eth.send_raw_transaction(signed_tx.raw_transaction)
        w3.eth.wait_for_transaction_receipt(signed_tx.hash)
        # 用户授权 Router（使用私钥签名）
        tx = token_a.functions.approve(router.address, 2**256 - 2).build_transaction({
            "from": user.address,
            "nonce": w3.eth.get_transaction_count(user.address),
            "gas": 100000,
            "gasPrice": w3.eth.gas_price
        })
        signed_tx = w3.eth.account.sign_transaction(tx, user_key)
        w3.eth.send_raw_transaction(signed_tx.raw_transaction)
        w3.eth.wait_for_transaction_receipt(signed_tx.hash)
    
    # 压测执行
    print(f"🔄 开始压测，并发用户数: {len(users)}")
    results = []
    errors = []
    start_time = time.time()

    def user_swap(user_data):
        nonlocal results, errors
        try:
            user = user_data["account"]
            user_key = user_data["key"]
            tx_start = time.time()
            # 构建交易
            tx = router.functions.swapExactTokensForTokens(
                SWAP_AMOUNT,
                0,
                [token_a.address, token_b.address],
                user.address
            ).build_transaction({
                "from": user.address,
                "nonce": w3.eth.get_transaction_count(user.address),
                "gas": 200000,
                "gasPrice": w3.eth.gas_price
            })
            # 签名并发送
            signed_tx = w3.eth.account.sign_transaction(tx, user_key)
            tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)
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
                "user": user_data["account"].address,
                "error": str(e)
            })

    # 多线程并发执行
    threads = []
    for user_data in users:
        t = threading.Thread(target=user_swap, args=(user_data,))
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
            "concurrent_users": len(users),
            "swap_amount": SWAP_AMOUNT,
            "network": RPC_URL
        },
        "results": {
            "total_txs": len(results) + len(errors),
            "success_txs": len(results),
            "failed_txs": len(errors),
            "success_rate": len(results) / (len(results) + len(errors)) * 100 if (len(results) + len(errors)) > 0 else 0,
            "total_time_ms": total_time * 1000,
            "avg_time_ms": sum(r["time_ms"] for r in results) / len(results) if results else 0,
            "avg_gas_used": sum(r["gas_used"] for r in results) / len(results) if results else 0,
            "throughput_tps": len(results) / total_time if total_time > 0 else 0
        },
        "detailed_results": results,
        "errors": errors
    }

    # 保存报告
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