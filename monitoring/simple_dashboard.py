#!/usr/bin/env python3
"""
简单的性能监控仪表盘 - 不依赖Docker
仅读取本地广播报告数据
"""
import time
import os
import json
from flask import Flask, render_template_string

app = Flask(__name__)

def get_broadcast_data():
    """获取广播目录中的交易数据"""
    data = {
        'tx_count': 0,
        'total_gas': 0,
        'total_txs': 0,
        'reports': []
    }
    
    broadcast_dir = "/home/liuyoushan/ape-demo/perf/broadcast"
    if os.path.exists(broadcast_dir):
        for root, dirs, files in os.walk(broadcast_dir):
            for f in files:
                if f.endswith('.json'):
                    data['tx_count'] += 1
                    file_path = os.path.join(root, f)
                    try:
                        with open(file_path, 'r') as file:
                            json_data = json.load(file)
                            txs = json_data.get('transactions', [])
                            receipts = json_data.get('receipts', [])
                            
                            report_gas = 0
                            report_txs = len(txs)
                            data['total_txs'] += report_txs
                            
                            # 尝试从 receipts 获取 gasUsed
                            for receipt in receipts:
                                if receipt and 'gasUsed' in receipt:
                                    try:
                                        report_gas += int(receipt['gasUsed'], 16)
                                    except:
                                        pass
                            
                            # 如果 receipts 为空，尝试从 transactions 获取
                            if report_gas == 0:
                                for tx in txs:
                                    if 'gasUsed' in tx and tx['gasUsed']:
                                        try:
                                            report_gas += int(tx['gasUsed'], 16) if isinstance(tx['gasUsed'], str) else tx['gasUsed']
                                        except:
                                            pass
                            
                            data['total_gas'] += report_gas
                            
                            report = {
                                'name': f,
                                'path': file_path,
                                'txs': report_txs,
                                'gas_used': report_gas
                            }
                            data['reports'].append(report)
                    except Exception as e:
                        pass
    
    return data

HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>区块链性能监控仪表盘</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
            min-height: 100vh;
            color: #fff;
            padding: 20px;
        }
        .header { text-align: center; margin-bottom: 30px; }
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
            background: linear-gradient(90deg, #00d4ff, #7c3aed);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }
        .header p { color: #8892b0; }
        .dashboard {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 20px;
            max-width: 1200px;
            margin: 0 auto;
        }
        .card {
            background: rgba(255, 255, 255, 0.05);
            backdrop-filter: blur(10px);
            border-radius: 16px;
            padding: 24px;
            border: 1px solid rgba(255, 255, 255, 0.1);
        }
        .card-title {
            font-size: 1.1em;
            color: #8892b0;
            margin-bottom: 15px;
            text-transform: uppercase;
            letter-spacing: 2px;
        }
        .card-value {
            font-size: 3em;
            font-weight: bold;
            background: linear-gradient(90deg, #00d4ff, #7c3aed);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }
        .card-unit {
            font-size: 1em;
            color: #8892b0;
            margin-left: 5px;
        }
        .report-list { max-height: 400px; overflow-y: auto; }
        .report-item {
            background: rgba(255, 255, 255, 0.05);
            border-radius: 8px;
            padding: 12px;
            margin-bottom: 10px;
        }
        .report-name {
            font-size: 0.9em;
            color: #ccd6f6;
            margin-bottom: 8px;
        }
        .report-meta {
            display: flex;
            gap: 12px;
            font-size: 0.8em;
        }
        .meta-item { display: flex; align-items: center; gap: 4px; }
        .meta-item.gas { color: #f59e0b; }
        .meta-item.txs { color: #00d4ff; }
        .status {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            margin-top: 15px;
        }
        .status-dot {
            width: 10px; height: 10px;
            background: #10b981;
            border-radius: 50%;
            animation: pulse 2s infinite;
        }
        @keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.5; } }
        .status-text { color: #10b981; font-size: 0.9em; }
        .timestamp {
            text-align: center;
            margin-top: 30px;
            color: #64ffda;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>⚡ 区块链性能监控</h1>
        <p>实时监控压测数据与交易指标</p>
    </div>
    
    <div class="dashboard">
        <div class="card">
            <div class="card-title">📊 报告文件数</div>
            <div class="card-value">{{ data.tx_count }}</div>
            <div class="card-unit">个报告</div>
        </div>
        
        <div class="card">
            <div class="card-title">📝 交易总数</div>
            <div class="card-value">{{ data.total_txs }}</div>
            <div class="card-unit">笔交易</div>
        </div>
        
        <div class="card">
            <div class="card-title">⛽ 总 Gas 消耗</div>
            <div class="card-value">{{ "{:,}".format(data.total_gas) }}</div>
            <div class="card-unit">Gas</div>
        </div>
        
        <div class="card" style="grid-column: span 2;">
            <div class="card-title">📋 广播报告详情</div>
            <div class="report-list">
                {% for report in data.reports %}
                <div class="report-item">
                    <div class="report-name">{{ report.name }}</div>
                    <div class="report-meta">
                        <div class="meta-item txs">
                            <span>📝</span>
                            <span>{{ report.txs }} txs</span>
                        </div>
                        <div class="meta-item gas">
                            <span>⛽</span>
                            <span>{{ "{:,}".format(report.gas_used) }} gas</span>
                        </div>
                    </div>
                </div>
                {% endfor %}
            </div>
            {% if not data.reports %}
            <div style="text-align: center; color: #64748b; padding: 20px;">暂无报告数据</div>
            {% endif %}
        </div>
    </div>
    
    <div class="status">
        <div class="status-dot"></div>
        <div class="status-text">监控服务运行中</div>
    </div>
    
    <div class="timestamp">
        更新时间: {{ timestamp }} | 刷新页面获取最新数据
    </div>
</body>
</html>
"""

@app.route('/')
def dashboard():
    data = get_broadcast_data()
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())
    return render_template_string(HTML_TEMPLATE, data=data, timestamp=timestamp)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=9000, debug=False)
