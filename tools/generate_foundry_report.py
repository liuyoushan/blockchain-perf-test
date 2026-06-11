#!/usr/bin/env python3
"""
Foundry 压测报告生成工具
解析 Foundry 广播文件中的事件日志，生成 JSON 报告
"""

import json
import os
import sys
from datetime import datetime

def parse_foundry_broadcast(broadcast_file):
    """解析 Foundry 广播文件，提取报告数据"""
    with open(broadcast_file, 'r') as f:
        data = json.load(f)
    
    report_data = {
        "timestamp": datetime.now().isoformat(),
        "test_name": os.path.basename(os.path.dirname(os.path.dirname(broadcast_file))),
        "transactions": [],
        "reports": {}
    }
    
    # 提取交易信息
    for tx in data.get('transactions', []):
        tx_info = {
            "hash": tx.get('hash'),
            "type": tx.get('transactionType'),
            "contract_name": tx.get('contractName'),
            "function": tx.get('function'),
            "gas": int(tx.get('transaction', {}).get('gas', '0x0'), 16)
        }
        report_data["transactions"].append(tx_info)
    
    # 提取事件日志中的报告数据
    for receipt in data.get('receipts', []):
        for log in receipt.get('logs', []):
            # 检查是否是 Report 事件
            if log.get('topics') and len(log.get('topics')) >= 1:
                topic0 = log.get('topics')[0]
                # Report 事件签名: keccak256("Report(string,uint256)")
                if topic0 == "0x73b53b48d57e6d575a9e6b99a1b24c5d3e3f7a0a5c5e8c9d7b6a5e4c3b2a1e0f":
                    try:
                        # 解析事件数据
                        # topics[1] = string key (32 bytes)
                        # data = uint256 value (32 bytes)
                        key = bytes.fromhex(log['topics'][1][2:]).decode('utf-8').strip('\x00')
                        value = int(log['data'], 16)
                        report_data["reports"][key] = value
                    except:
                        pass
    
    # 计算统计数据
    receipts = data.get('receipts', [])
    success_count = sum(1 for r in receipts if r.get('status') == '0x1')
    total_gas = sum(int(r.get('gasUsed', '0x0'), 16) for r in receipts)
    
    report_data["results"] = {
        "total_txs": len(receipts),
        "success_txs": success_count,
        "failed_txs": len(receipts) - success_count,
        "success_rate": success_count / len(receipts) * 100 if receipts else 0,
        "total_gas_used": total_gas,
        "avg_gas_used": total_gas / len(receipts) if receipts else 0
    }
    
    return report_data

def generate_reports(broadcast_dir, output_dir):
    """为所有广播文件生成报告"""
    os.makedirs(output_dir, exist_ok=True)
    
    for root, dirs, files in os.walk(broadcast_dir):
        for f in files:
            if f.endswith('.json') and f.startswith('run-'):
                broadcast_file = os.path.join(root, f)
                try:
                    report = parse_foundry_broadcast(broadcast_file)
                    script_name = os.path.basename(os.path.dirname(os.path.dirname(broadcast_file)))
                    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
                    report_filename = f"{output_dir}/foundry_{script_name}_{timestamp}.json"
                    
                    with open(report_filename, 'w') as f:
                        json.dump(report, f, indent=2)
                    
                    print(f"✅ 报告已生成: {report_filename}")
                except Exception as e:
                    print(f"❌ 解析失败 {broadcast_file}: {e}")

if __name__ == "__main__":
    broadcast_dir = "/home/liuyoushan/blockchain-perf-test/build/broadcast"
    output_dir = "/home/liuyoushan/blockchain-perf-test/reports/foundry"
    
    if len(sys.argv) > 1:
        broadcast_dir = sys.argv[1]
    if len(sys.argv) > 2:
        output_dir = sys.argv[2]
    
    generate_reports(broadcast_dir, output_dir)
