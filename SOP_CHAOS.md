# 混沌工程测试标准操作流程 (SOP)

## 文档版本
- 版本：v1.0
- 日期：2026-06-09
- 适用范围：ape-demo/perf 混沌工程测试框架
- 特点：验证系统在极端条件下的稳定性和容错能力

---

## 目录
1. [混沌工程概述](#一混沌工程概述)
2. [环境准备](#二环境准备)
3. [测试场景说明](#三测试场景说明)
4. [执行混沌测试](#四执行混沌测试)
5. [结果分析](#五结果分析)
6. [常用命令速查](#六常用命令速查)
7. [问题排查](#七问题排查)

---

## 一、混沌工程概述

### 1.1 什么是混沌工程

混沌工程是一种**主动式稳定性测试方法**，通过在系统中**故意引入故障和异常**，来验证系统在极端条件下的行为和恢复能力。

### 1.2 核心概念

| 概念 | 说明 |
|------|------|
| **稳态假设** | 定义系统正常运行时的关键指标（如 TPS、延迟、成功率） |
| **注入故障** | 主动引入各种故障场景（网络延迟、节点宕机、资源限制等） |
| **验证结果** | 观察系统是否仍能在可接受范围内运行 |
| **学习改进** | 根据测试结果优化系统稳定性 |

### 1.3 区块链场景下的混沌测试

```
┌─────────────────────────────────────────────────────────────┐
│                   混沌工程测试架构                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │  故障注入    │    │  性能测试    │    │  结果分析    │  │
│  │              │    │              │    │              │  │
│  │ 网络延迟     │    │ Gas基准测试  │    │ 成功率下降   │  │
│  │ 网络丢包     │    │ 单区块负载   │    │ 失败数统计   │  │
│  │ 节点故障     │    │ 多用户并发   │    │ 恢复能力验证 │  │
│  │ 资源限制     │    │              │    │              │  │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘  │
│         │                   │                    │          │
│         └───────────────────┼────────────────────┘          │
│                             ▼                               │
│                    ┌──────────────┐                         │
│                    │   测试报告   │                         │
│                    │  (JSON格式)  │                         │
│                    └──────────────┘                         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 二、环境准备

### 2.1 前置依赖

| 依赖 | 版本要求 | 安装方式 |
|------|----------|----------|
| Foundry | >= 0.2.0 | `curl -L https://foundry.paradigm.xyz \| bash` |
| Python | >= 3.8 | 系统自带或官网安装 |
| Anvil | 随Foundry安装 | 自动安装 |

### 2.2 权限要求

| 测试场景 | 需要root权限 | 说明 |
|----------|--------------|------|
| network_delay | ✅ 需要 | 使用 `tc` 命令修改网络配置 |
| packet_loss | ✅ 需要 | 使用 `tc` 命令修改网络配置 |
| node_failure | ❌ 不需要 | 使用 `pkill` 命令 |
| resource_limit | ⚠️ 可选 | 需要 `cpulimit` 工具 |
| transaction_failure | ❌ 不需要 | 纯逻辑模拟 |
| high_latency | ❌ 不需要 | 使用 `sleep` 模拟 |

### 2.3 验证依赖

```bash
# 验证 Foundry
forge --version

# 验证 Python
python3 --version

# 验证 Anvil
anvil --version

# 验证网络工具（可选，用于完整版）
which tc
which cpulimit
```

---

## 三、测试场景说明

### 3.1 网络延迟测试 (network_delay)

**目标**：验证系统在高延迟网络环境下的响应能力

**实现原理**：
```bash
# 注入 200ms 网络延迟
tc qdisc add dev eth0 root netem delay 200ms

# 恢复网络
tc qdisc del dev eth0 root
```

**验证指标**：
- 交易成功率下降百分比
- 平均响应时间增加
- 系统是否出现超时

---

### 3.2 网络丢包测试 (packet_loss)

**目标**：验证系统在网络不稳定环境下的容错能力

**实现原理**：
```bash
# 注入 10% 丢包率
tc qdisc add dev eth0 root netem loss 10%

# 恢复网络
tc qdisc del dev eth0 root
```

**验证指标**：
- 交易重试成功率
- 系统错误处理能力
- 数据一致性

---

### 3.3 节点故障测试 (node_failure)

**目标**：验证系统在节点崩溃后的恢复能力

**实现原理**：
```bash
# 停止节点
pkill anvil

# 等待停机时间
sleep 5

# 重启节点
anvil --host 127.0.0.1 --port 8545 &
```

**验证指标**：
- 节点重启时间
- 交易恢复成功率
- 数据完整性

---

### 3.4 资源限制测试 (resource_limit)

**目标**：验证系统在资源受限环境下的表现

**实现原理**：
```bash
# 限制 CPU 使用率为 50%
cpulimit -e anvil -l 50

# 限制内存使用
ulimit -v 524288
```

**验证指标**：
- 系统响应时间
- 交易处理能力
- 资源使用效率

---

### 3.5 交易失败注入 (transaction_failure)

**目标**：验证系统对交易失败的处理能力

**实现原理**：
```python
# 随机丢弃部分交易
if random.random() < failure_rate:
    return {"status": "failed", "error": "simulated failure"}
```

**验证指标**：
- 失败交易处理
- 错误信息准确性
- 系统稳定性

---

### 3.6 高延迟模拟 (high_latency)

**目标**：验证系统在高延迟场景下的表现

**实现原理**：
```python
# 模拟高延迟
time.sleep(delay_ms / 1000)
```

**验证指标**：
- 系统响应时间
- 超时处理
- 用户体验

---

## 四、执行混沌测试

### 4.1 启动测试节点

打开 **终端1**，执行：

```bash
# 启动本地测试节点
anvil --host 127.0.0.1 --port 8545 --block-time 1

# 预期输出：
#    ____    __
#   / __/___/ /  ___
#  / _// __/ _ \/ _ \
# /___/\__/_//_/\___/
#
# Anvil v0.10.10 (commit xxx)
#
# Listening on 127.0.0.1:8545
```

### 4.2 使用启动脚本（推荐）

打开 **终端2**，执行：

```bash
# 进入 perf 目录
cd /home/liuyoushan/ape-demo/perf

# 运行混沌测试启动脚本
./chaos/run_chaos.sh
```

**交互式菜单：**
```
==============================================
        区块链混沌工程测试套件
==============================================
请选择测试模式:
1. 完整版 (需要root权限，支持网络级故障注入)
2. 简化版 (无需root权限，基础稳定性测试)
输入选择 (1/2): 
```

### 4.3 使用完整版混沌引擎

**需要 root 权限**

```bash
# 进入 perf 目录
cd /home/liuyoushan/ape-demo/perf

# 运行完整版混沌引擎
sudo python3 chaos/chaos_engine.py
```

**可用场景：**
```
==============================================
     区块链混沌工程测试引擎
==============================================
可用场景:
  1. network_delay  - 网络延迟测试
  2. packet_loss    - 网络丢包测试
  3. node_failure   - 节点故障测试
  4. resource_limit - 资源限制测试
  5. all            - 运行所有场景
==============================================
请选择测试场景 (输入数字或 'all'): 
```

### 4.4 使用简化版混沌引擎

**无需 root 权限**

```bash
# 进入 perf 目录
cd /home/liuyoushan/ape-demo/perf

# 运行简化版混沌引擎
python3 chaos/chaos_simple.py
```

**可用场景：**
```
==============================================
     简化版混沌工程测试
     (无需root权限)
==============================================
可用场景:
  1. transaction_failure - 交易失败注入
  2. high_latency        - 高延迟测试
  3. slow_node           - 节点响应变慢
  4. all                 - 运行所有场景
==============================================
请选择测试场景: 
```

### 4.5 执行单个场景测试

```bash
# 示例：执行网络延迟测试
cd /home/liuyoushan/ape-demo/perf

# 设置测试私钥
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff943c21ee9409cbe98727d6c8d49c89426

# 运行单个场景
python3 -c "
from chaos.chaos_engine import BlockchainChaosEngine
engine = BlockchainChaosEngine()
result = engine.run_chaos_scenario('network_delay')
print(f'成功率下降: {result[\"impact\"][\"success_rate_drop_pct\"]}%')
"
```

---

## 五、结果分析

### 5.1 测试报告结构

测试完成后，报告自动保存到 `chaos/reports/` 目录：

```bash
# 查看报告目录
ls -la chaos/reports/

# 报告文件命名格式
# chaos_report_YYYYMMDD_HHMMSS.json
# chaos_simple_report_YYYYMMDD_HHMMSS.json
```

### 5.2 报告内容解析

```json
{
  "test_suite": "Blockchain Chaos Engineering Test",
  "timestamp": "2026-06-09T10:30:00",
  "results": [
    {
      "scenario": "network_delay",
      "description": "网络延迟测试",
      "timestamp": "2026-06-09T10:30:00",
      "baseline": {
        "success_count": 50,
        "fail_count": 0,
        "return_code": 0
      },
      "failure": {
        "success_count": 42,
        "fail_count": 8,
        "return_code": 0
      },
      "recovery": {
        "success_count": 50,
        "fail_count": 0,
        "return_code": 0
      },
      "impact": {
        "success_rate_drop_pct": 16.0,
        "failures_introduced": 8
      }
    }
  ],
  "summary": {
    "total_scenarios": 4,
    "scenarios_tested": ["network_delay", "packet_loss", "node_failure", "resource_limit"],
    "impact_summary": [...]
  }
}
```

### 5.3 关键指标说明

| 指标 | 说明 | 健康阈值 |
|------|------|----------|
| **baseline** | 基准性能（无故障时） | 成功率 100% |
| **failure** | 故障条件下性能 | 成功率 > 80% |
| **recovery** | 恢复后性能 | 成功率 100% |
| **success_rate_drop_pct** | 成功率下降百分比 | < 20% |
| **failures_introduced** | 新增失败数 | < 10 |

### 5.4 结果评估标准

| 等级 | 成功率下降 | 说明 |
|------|------------|------|
| ✅ 优秀 | < 10% | 系统对故障不敏感，稳定性极佳 |
| ⚠️ 良好 | 10% - 20% | 系统有一定容错能力 |
| ❌ 需改进 | > 20% | 系统对故障敏感，需要优化 |

### 5.5 结果对比分析

```bash
# 查看所有测试报告
cd /home/liuyoushan/ape-demo/perf/chaos/reports

# 对比不同时间的测试结果
cat chaos_report_20260609_103000.json | jq '.summary'
cat chaos_report_20260609_110000.json | jq '.summary'

# 提取关键指标
cat chaos_report_*.json | jq '.results[].impact'
```

---

## 六、常用命令速查

### 6.1 测试执行命令

| 操作 | 命令 |
|------|------|
| 启动脚本 | `./chaos/run_chaos.sh` |
| 完整版引擎 | `sudo python3 chaos/chaos_engine.py` |
| 简化版引擎 | `python3 chaos/chaos_simple.py` |
| 查看报告 | `cat chaos/reports/chaos_report_*.json \| jq .` |

### 6.2 故障注入命令

| 操作 | 命令 |
|------|------|
| 网络延迟 | `tc qdisc add dev eth0 root netem delay 200ms` |
| 网络丢包 | `tc qdisc add dev eth0 root netem loss 10%` |
| 恢复网络 | `tc qdisc del dev eth0 root` |
| 停止节点 | `pkill anvil` |
| 启动节点 | `anvil --host 127.0.0.1 --port 8545 &` |
| CPU限制 | `cpulimit -e anvil -l 50` |

### 6.3 监控命令

| 操作 | 命令 |
|------|------|
| 查看节点进程 | `ps aux \| grep anvil` |
| 查看网络配置 | `tc qdisc show` |
| 查看系统资源 | `top -p $(pgrep anvil)` |
| 查看端口占用 | `ss -tlnp \| grep 8545` |

---

## 七、问题排查

### 7.1 常见错误

| 错误类型 | 错误信息 | 解决方案 |
|----------|----------|----------|
| 权限不足 | `Operation not permitted` | 使用 `sudo` 运行 |
| 节点未启动 | `Connection refused` | 先启动 Anvil 节点 |
| 网络工具缺失 | `tc: command not found` | 安装 `iproute2` 包 |
| CPU限制工具缺失 | `cpulimit: command not found` | 安装 `cpulimit` 包 |

### 7.2 故障恢复

如果测试过程中出现异常，可以手动恢复：

```bash
# 恢复网络配置
sudo tc qdisc del dev eth0 root

# 重启节点
pkill anvil
anvil --host 127.0.0.1 --port 8545 --block-time 1 &

# 清理 CPU 限制
pkill cpulimit
```

### 7.3 调试技巧

```bash
# 查看详细日志
python3 chaos/chaos_engine.py 2>&1 | tee chaos_debug.log

# 检查网络状态
tc qdisc show dev eth0

# 监控系统资源
watch -n 1 'ps aux | grep anvil'
```

---

## 附录：混沌测试最佳实践

### 1. 测试前准备
- 确保系统有足够的资源
- 备份重要数据
- 通知相关人员

### 2. 测试中监控
- 实时观察系统指标
- 记录异常行为
- 准备回滚方案

### 3. 测试后分析
- 对比基准数据
- 分析失败原因
- 制定优化方案

### 4. 持续改进
- 定期执行混沌测试
- 更新测试场景
- 优化系统架构

---

**文档结束**

---

> 📌 **提示**：混沌工程测试是验证系统稳定性的重要手段，建议在测试环境中进行，避免在生产环境中执行可能影响服务的故障注入操作。
