#!/usr/bin/env python3
import time
from flask import Flask
import os
import json

app = Flask(__name__)

def get_tx_count():
    count = 0
    # 使用绝对路径，确保无论从哪个目录运行都能找到
    broadcast_dir = '/home/liuyoushan/blockchain-perf-test/build/broadcast'
    if os.path.exists(broadcast_dir):
        for root, dirs, files in os.walk(broadcast_dir):
            for f in files:
                if f.endswith('.json'):
                    file_path = os.path.join(root, f)
                    try:
                        with open(file_path, 'r') as file:
                            data = json.load(file)
                            # Foundry 广播文件格式：transactions 数组
                            transactions = data.get('transactions', [])
                            count += len(transactions)
                    except Exception as e:
                        pass
    return count

def get_gas_used():
    total_gas = 0
    # 使用绝对路径，确保无论从哪个目录运行都能找到
    broadcast_dir = '/home/liuyoushan/blockchain-perf-test/build/broadcast'
    if os.path.exists(broadcast_dir):
        for root, dirs, files in os.walk(broadcast_dir):
            for f in files:
                if f.endswith('.json'):
                    file_path = os.path.join(root, f)
                    try:
                        with open(file_path, 'r') as file:
                            data = json.load(file)
                            # Foundry 广播文件格式：receipts 数组是独立的
                            receipts = data.get('receipts', [])
                            for receipt in receipts:
                                gas = receipt.get('gasUsed')
                                if gas:
                                    total_gas += int(gas, 16) if isinstance(gas, str) else gas
                    except Exception as e:
                        pass
    return total_gas

@app.route('/metrics')
def metrics():
    timestamp = int(time.time())
    tx_count = get_tx_count()
    gas_used = get_gas_used()
    
    metrics_text = """# HELP eth_transaction_count_total Total transactions
# TYPE eth_transaction_count_total gauge
eth_transaction_count_total {}

# HELP eth_total_gas_used Total gas used
# TYPE eth_total_gas_used gauge
eth_total_gas_used {}

# HELP eth_scrape_timestamp Scrape timestamp
# TYPE eth_scrape_timestamp gauge
eth_scrape_timestamp {}
""".format(tx_count, gas_used, timestamp)
    return metrics_text, 200, {'Content-Type': 'text/plain; version=0.0.4; charset=utf-8'}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=9102)
