#!/usr/bin/env python3
"""
清算业务压测脚本（框架）
输出 JSON 报告到 perf/reports/ 目录 + Prometheus 时序指标埋点
"""

import json
import time
import threading
import os
from datetime import datetime
from prometheus_client import start_http_server, Counter, Gauge, Histogram

from ape import accounts, networks

# ===================== 监控指标定义 =====================
# 全局指标，所有线程共享
TX_TOTAL = Counter("perf_tx_total", "所有发起交易总数")
TX_SUCCESS = Counter("perf_tx_success", "成功清算交易数")
TX_FAILED = Counter("perf_tx_failed", "失败交易数")
TX_GAS = Histogram("perf_tx_gas_used", "单笔交易Gas消耗", buckets=[50000,100000,150000,200000,300000])
TX_LATENCY = Histogram("perf_tx_latency_ms", "单笔交易耗时ms", buckets=[50,100,200,500,1000,2000])
CURRENT_TPS = Gauge("perf_current_tps", "实时TPS")

# 配置参数
CONCURRENT_USERS = 10
REPORT_DIR = "../reports"
# 长时压测开关：True=循环持续跑（常驻进程，Grafana持续有数据）；False=只跑一轮基准
LONG_RUN_STRESS = True
LOOP_INTERVAL = 2  # 每轮压测间隔秒

def single_round_test():
    """单轮压测逻辑，抽离出来支持循环长时跑"""
    # 连接本地网络
    with networks.parse_network_choice("local"):
        deployer = accounts.test_accounts[0]
        # TODO: 部署清算相关合约
        # liquidator = project.Liquidator.deploy(sender=deployer)
        users = accounts.test_accounts[1:CONCURRENT_USERS + 1]

        results = []
        errors = []
        start_time = time.time()

        def user_liquidation(user):
            nonlocal results, errors
            try:
                tx_start = time.time()
                # TODO: 执行清算操作
                # receipt = liquidator.liquidate(..., sender=user)
                tx_time = time.time() - tx_start
                gas = 150000

                # 更新Prometheus指标
                TX_TOTAL.inc()
                TX_SUCCESS.inc()
                TX_GAS.observe(gas)
                TX_LATENCY.observe(tx_time * 1000)

                results.append({
                    "user": str(user),
                    "tx_hash": "0x" + "0" * 64,
                    "gas_used": gas,
                    "time_ms": tx_time * 1000
                })
            except Exception as e:
                TX_TOTAL.inc()
                TX_FAILED.inc()
                errors.append({
                    "user": str(user),
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
        CURRENT_TPS.set(tps)

        # 生成单轮JSON报告
        report = {
            "timestamp": datetime.now().isoformat(),
            "test_name": "Liquidation Stress Test",
            "config": {"concurrent_users": CONCURRENT_USERS, "network": "local"},
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
    # 启动Prometheus指标服务，绑定0.0.0.0允许Docker容器访问
    start_http_server(port=8000, addr="0.0.0.0")
    print("✅ Prometheus metrics server started on 0.0.0.0:8000")

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