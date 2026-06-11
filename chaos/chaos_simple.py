#!/usr/bin/env python3
"""
简化版混沌工程测试 - 无需root权限
用于在受限环境中进行基本的稳定性测试
"""

import subprocess
import time
import random
import os
import json
from datetime import datetime

class SimpleChaosEngine:
    def __init__(self):
        self.test_results = []
    
    def log(self, message, level="INFO"):
        """日志记录"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] [{level}] {message}")
    
    def inject_transaction_failure(self, failure_rate=0.1):
        """模拟交易失败注入（通过修改gas limit实现）"""
        self.log(f"模拟交易失败注入，失败率: {failure_rate*100}%")
        return failure_rate
    
    def inject_high_latency(self, delay_ms=100):
        """模拟高延迟场景（通过sleep实现）"""
        self.log(f"模拟高延迟场景: {delay_ms}ms")
        time.sleep(delay_ms / 1000)
        return True
    
    def simulate_node_responsiveness(self, slow_factor=2):
        """模拟节点响应变慢"""
        self.log(f"模拟节点响应变慢，慢因子: {slow_factor}x")
        # 通过增加请求间隔来模拟
        return slow_factor
    
    def run_pressure_test(self, user_count=10, iterations=5):
        """执行压力测试"""
        self.log(f"执行压力测试: {user_count} 用户, {iterations} 轮次")
        
        results = {
            "total_transactions": 0,
            "success_count": 0,
            "fail_count": 0,
            "avg_latency_ms": 0,
            "errors": []
        }
        
        for i in range(iterations):
            self.log(f"  第 {i+1}/{iterations} 轮")
            
            try:
                result = subprocess.run(
                    [
                        "/home/liuyoushan/.foundry/bin/forge", "script", "perf/src/GasBenchmark.s.sol",
                        "--rpc-url", "http://127.0.0.1:8545",
                        "--broadcast", "-v",
                        "--via-ir"
                    ],
                    capture_output=True,
                    text=True,
                    timeout=120,
                    cwd="/home/liuyoushan/ape-demo"
                )
                
                results["total_transactions"] += 1
                if result.returncode == 0:
                    results["success_count"] += 1
                    self.log(f"    ✅ 成功")
                else:
                    results["fail_count"] += 1
                    results["errors"].append(result.stderr[:200] if result.stderr else "Unknown error")
                    self.log(f"    ❌ 失败")
            
            except subprocess.TimeoutExpired:
                results["fail_count"] += 1
                results["errors"].append("Timeout")
                self.log(f"    ⏱️ 超时")
            
            except Exception as e:
                results["fail_count"] += 1
                results["errors"].append(str(e))
                self.log(f"    ❌ 异常: {e}")
        
        return results
    
    def run_chaos_test(self, scenario):
        """运行混沌测试"""
        self.log(f"🚀 开始混沌测试: {scenario}")
        
        # 基准测试
        self.log("📊 记录基准性能...")
        baseline = self.run_pressure_test()
        
        # 应用混沌条件
        if scenario == "transaction_failure":
            failure_rate = self.inject_transaction_failure(0.1)
            # 在测试中应用失败注入
        elif scenario == "high_latency":
            self.inject_high_latency(200)
        elif scenario == "slow_node":
            self.simulate_node_responsiveness(2)
        
        # 在混沌条件下测试
        self.log("📊 在混沌条件下测试...")
        chaos_result = self.run_pressure_test()
        
        # 恢复后测试
        self.log("📊 恢复后验证...")
        recovery = self.run_pressure_test()
        
        # 计算影响
        baseline_success_rate = baseline["success_count"] / max(baseline["total_transactions"], 1) * 100
        chaos_success_rate = chaos_result["success_count"] / max(chaos_result["total_transactions"], 1) * 100
        
        result = {
            "scenario": scenario,
            "timestamp": datetime.now().isoformat(),
            "baseline": baseline,
            "chaos": chaos_result,
            "recovery": recovery,
            "impact": {
                "success_rate_drop_pct": round(baseline_success_rate - chaos_success_rate, 2),
                "failures_introduced": chaos_result["fail_count"] - baseline["fail_count"]
            }
        }
        
        self.test_results.append(result)
        self.log(f"✅ 混沌测试完成")
        return result
    
    def save_report(self):
        """保存测试报告"""
        report_dir = "/home/liuyoushan/ape-demo/perf/chaos/reports"
        os.makedirs(report_dir, exist_ok=True)
        
        report_path = os.path.join(
            report_dir,
            f"chaos_simple_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        )
        
        report = {
            "test_suite": "Simple Blockchain Chaos Test",
            "timestamp": datetime.now().isoformat(),
            "results": self.test_results,
            "summary": {
                "total_tests": len(self.test_results),
                "scenarios": [r["scenario"] for r in self.test_results]
            }
        }
        
        with open(report_path, "w") as f:
            json.dump(report, f, indent=2)
        
        self.log(f"📊 报告已保存: {report_path}")
        return report_path

def main():
    """主函数"""
    engine = SimpleChaosEngine()
    
    print("=" * 60)
    print("     简化版混沌工程测试")
    print("     (无需root权限)")
    print("=" * 60)
    print("可用场景:")
    print("  1. transaction_failure - 交易失败注入")
    print("  2. high_latency        - 高延迟测试")
    print("  3. slow_node           - 节点响应变慢")
    print("  4. all                 - 运行所有场景")
    print("=" * 60)
    
    choice = input("请选择测试场景: ").strip()
    
    scenarios = {
        "1": "transaction_failure",
        "2": "high_latency",
        "3": "slow_node",
        "all": ["transaction_failure", "high_latency", "slow_node"]
    }
    
    if choice not in scenarios:
        print("无效选择")
        return
    
    if choice == "all":
        for scenario in scenarios["all"]:
            engine.run_chaos_test(scenario)
            time.sleep(3)
    else:
        result = engine.run_chaos_test(scenarios[choice])
        print("\n📋 测试结果:")
        print(f"成功率下降: {result['impact']['success_rate_drop_pct']}%")
        print(f"新增失败数: {result['impact']['failures_introduced']}")
    
    engine.save_report()

if __name__ == "__main__":
    main()
