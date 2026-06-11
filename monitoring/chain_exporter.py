#!/usr/bin/env python3
import time
from flask import Flask
import os
import json

app = Flask(__name__)

def get_tx_count():
    count = 0
    broadcast_dir = "/home/liuyoushan/ape-demo/perf/broadcast"
    if os.path.exists(broadcast_dir):
        for root, dirs, files in os.walk(broadcast_dir):
            for f in files:
                if f.endswith('.json'):
                    count += 1
    return count

def get_gas_used():
    total_gas = 0
    broadcast_dir = "/home/liuyoushan/ape-demo/perf/broadcast"
    if os.path.exists(broadcast_dir):
        for root, dirs, files in os.walk(broadcast_dir):
            for f in files:
                if f.endswith('.json'):
                    file_path = os.path.join(root, f)
                    try:
                        with open(file_path, 'r') as file:
                            data = json.load(file)
                            for receipt in data.get('receipts', []):
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
