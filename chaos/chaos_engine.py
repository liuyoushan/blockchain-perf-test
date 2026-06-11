#!/usr/bin/env python3
"""
混沌工程测试引擎 - Blockchain Chaos Engineering Engine
用于验证区块链系统在极端条件下的稳定性和容错能力
"""

import subprocess
import time
import random
import os
import json
from datetime import datetime

class BlockchainChaosEngine:
    def __init__(self):
        self.node_pid = None
        self.test_results = []
    
    def log(self, message, level="INFO"):
        """日志记录"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] [{level}] {message}")
    
    def inject_network_delay(self, delay_ms=200):
        """注入网络延迟"""
        try:
            self.log(f"注入网络延迟: {delay_ms}ms")
            subprocess.run(
                ["tc", "qdisc", "add", "dev", "eth0", "root", "netem", "delay", f"{delay_ms}ms"],
                check=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            return True
        except subprocess.CalledProcessError:
            self.log("网络延迟注入失败，可能需要root权限", "WARN")
            return False
    
    def inject_packet_loss(self, loss_percent=10):
        """注入网络丢包"""
        try:
            self.log(f"注入网络丢包: {loss_percent}%")
            subprocess.run(
                ["tc", "qdisc", "add", "dev", "eth0", "root", "netem", "loss", f"{loss_percent}%"],
                check=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            return True
        except subprocess.CalledProcessError:
            self.log("网络丢包注入失败，可能需要root权限", "WARN")
            return False
    
    def inject_node_failure(self, downtime_seconds=5):
        """模拟节点故障（停止后重启）"""
        self.log(f"模拟节点故障，停机时间: {downtime_seconds}秒")
        
        # 停止节点
        try:
            subprocess.run(["pkill", "anvil"], stderr=subprocess.DEVNULL)
            self.log("节点已停止")
        except Exception as e:
            self.log(f"停止节点时出错: {e}", "WARN")
        
        # 等待停机时间
        time.sleep(downtime_seconds)
        
        # 重启节点
        try:
            subprocess.Popen(
                ["/home/liuyoushan/.foundry/bin/anvil", "--host", "127.0.0.1", "--port", "8545", "--block-time", "1"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            self.log("节点已重启")
            time.sleep(3)  # 等待节点启动
            return True
        except Exception as e:
            self.log(f"重启节点时出错: {e}", "ERROR")
            return False
    
    def inject_resource_limit(self, cpu_limit=50, memory_limit_mb=512):
        """限制资源使用"""
        self.log(f"限制资源: CPU={cpu_limit}%, 内存={memory_limit_mb}MB")
        try:
            # 查找 anvil 进程
            result = subprocess.run(
                ["pgrep", "anvil"],
                capture_output=True,
                text=True
            )
            if result.stdout:
                pid = result.stdout.strip()
                # 使用 cpulimit 限制 CPU
                subprocess.Popen(
                    ["cpulimit", "-p", pid, "-l", str(cpu_limit)],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL
                )
                self.log(f"CPU 限制已应用到进程 {pid}")
                return True
            else:
                self.log("未找到 anvil 进程", "WARN")
                return False
        except FileNotFoundError:
            self.log("cpulimit 未安装，跳过资源限制", "INFO")
            return False
        except Exception as e:
            self.log(f"资源限制失败: {e}", "ERROR")
            return False
    
    def restore(self):
        """恢复系统状态"""
        self.log("恢复系统状态")
        try:
            subprocess.run(
                ["tc", "qdisc", "del", "dev", "eth0", "root"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            self.log("网络规则已清除")
        except Exception:
            pass  # 忽略错误，可能规则已不存在
        
        try:
            subprocess.run(["pkill", "cpulimit"], stderr=subprocess.DEVNULL)
            self.log("CPU限制进程已终止")
        except Exception:
            pass
    
    def run_performance_test(self, script_path="perf/src/MultiUserConcurrent.s.sol"):
        """执行性能测试"""
        self.log(f"执行性能测试: {script_path}")
        result = subprocess.run(
            [
                "/home/liuyoushan/.foundry/bin/forge", "script", script_path,
                "--rpc-url", "http://127.0.0.1:8545",
                "--broadcast", "-v",
                "--via-ir"
            ],
            capture_output=True,
            text=True,
            timeout=300,
            cwd="/home/liuyoushan/ape-demo"
        )
        
        # 解析测试结果
        success_count = result.stdout.count("✅")
        fail_count = result.stdout.count("❌")
        gas_used = 0
        
        if "Total Paid:" in result.stdout:
            gas_start = result.stdout.find("Total Paid:")
            gas_end = result.stdout.find("\n", gas_start)
            gas_info = result.stdout[gas_start:gas_end]
        else:
            gas_info = "N/A"
        
        return {
            "success_count": success_count,
            "fail_count": fail_count,
            "return_code": result.returncode,
            "gas_info": gas_info,
            "stdout": result.stdout[-2000:] if len(result.stdout) > 2000 else result.stdout
        }
    
    def run_chaos_scenario(self, scenario_name, duration_minutes=5):
        """运行单个混沌测试场景"""
        self.log(f"🚀 开始混沌测试场景: {scenario_name}")
        
        scenarios = {
            "network_delay": {
                "inject": lambda: self.inject_network_delay(),
                "description": "网络延迟测试"
            },
            "packet_loss": {
                "inject": lambda: self.inject_packet_loss(),
                "description": "网络丢包测试"
            },
            "node_failure": {
                "inject": lambda: self.inject_node_failure(),
                "description": "节点故障测试"
            },
            "resource_limit": {
                "inject": lambda: self.inject_resource_limit(),
                "description": "资源限制测试"
            }
        }
        
        if scenario_name not in scenarios:
            self.log(f"未知场景: {scenario_name}", "ERROR")
            return None
        
        # 记录基准性能
        self.log("记录基准性能指标...")
        baseline_result = self.run_performance_test()
        
        # 注入故障
        success = scenarios[scenario_name]["inject"]()
        if not success:
            self.log(f"故障注入失败，跳过场景 {scenario_name}", "WARN")
            return None
        
        # 等待故障生效
        time.sleep(2)
        
        # 在故障条件下执行测试
        self.log("在故障条件下执行性能测试...")
        failure_result = self.run_performance_test()
        
        # 恢复系统
        self.restore()
        time.sleep(2)
        
        # 恢复后验证
        self.log("验证系统恢复状态...")
        recovery_result = self.run_performance_test()
        
        # 整理测试结果
        result = {
            "scenario": scenario_name,
            "description": scenarios[scenario_name]["description"],
            "timestamp": datetime.now().isoformat(),
            "baseline": baseline_result,
            "failure": failure_result,
            "recovery": recovery_result,
            "impact": {
                "success_rate_drop": round(
                    ((baseline_result["success_count"] - failure_result["success_count"]) / 
                     max(baseline_result["success_count"], 1)) * 100, 2
                ),
                "failures_introduced": failure_result["fail_count"]
            }
        }
        
        self.test_results.append(result)
        self.log(f"✅ 混沌测试场景完成: {scenario_name}")
        return result
    
    def run_all_scenarios(self):
        """运行所有混沌测试场景"""
        self.log("🔮 开始完整混沌测试套件")
        
        scenarios = ["network_delay", "packet_loss", "node_failure", "resource_limit"]
        
        for scenario in scenarios:
            self.run_chaos_scenario(scenario)
            time.sleep(5)  # 场景间间隔
        
        # 保存测试报告
        self.save_report()
    
    def save_report(self):
        """保存测试报告"""
        report_dir = "/home/liuyoushan/ape-demo/perf/chaos/reports"
        os.makedirs(report_dir, exist_ok=True)
        
        report_path = os.path.join(
            report_dir,
            f"chaos_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        )
        
        report = {
            "test_suite": "Blockchain Chaos Engineering Test",
            "timestamp": datetime.now().isoformat(),
            "results": self.test_results,
            "summary": self.generate_summary()
        }
        
        with open(report_path, "w") as f:
            json.dump(report, f, indent=2)
        
        self.log(f"📊 测试报告已保存: {report_path}")
        return report_path
    
    def generate_summary(self):
        """生成测试摘要"""
        if not self.test_results:
            return {"total_scenarios": 0, "passed": 0, "failed": 0}
        
        summary = {
            "total_scenarios": len(self.test_results),
            "scenarios_tested": [r["scenario"] for r in self.test_results],
            "impact_summary": []
        }
        
        for result in self.test_results:
            impact = result["impact"]
            summary["impact_summary"].append({
                "scenario": result["scenario"],
                "success_rate_drop_pct": impact["success_rate_drop"],
                "failures_introduced": impact["failures_introduced"]
            })
        
        return summary

def main():
    """主函数"""
    engine = BlockchainChaosEngine()
    
    print("=" * 60)
    print("     区块链混沌工程测试引擎")
    print("=" * 60)
    print("可用场景:")
    print("  1. network_delay  - 网络延迟测试")
    print("  2. packet_loss    - 网络丢包测试")
    print("  3. node_failure   - 节点故障测试")
    print("  4. resource_limit - 资源限制测试")
    print("  5. all            - 运行所有场景")
    print("=" * 60)
    
    choice = input("请选择测试场景 (输入数字或 'all'): ").strip()
    
    scenario_map = {
        "1": "network_delay",
        "2": "packet_loss",
        "3": "node_failure",
        "4": "resource_limit",
        "all": "all"
    }
    
    if choice not in scenario_map:
        print("无效选择")
        return
    
    if choice == "all":
        engine.run_all_scenarios()
    else:
        result = engine.run_chaos_scenario(scenario_map[choice])
        if result:
            print("\n📋 测试结果:")
            print(f"场景: {result['description']}")
            print(f"成功率下降: {result['impact']['success_rate_drop']}%")
            print(f"新增失败数: {result['impact']['failures_introduced']}")
            engine.save_report()

if __name__ == "__main__":
    main()
