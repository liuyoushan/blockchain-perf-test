# 区块链性能测试结果分析指南

## 文档目的

本指南用于指导如何判断测试是否通过，以及如何分析测试结果。

---

## 一、测试通过的核心判断原则

### 1.1 统一判断标准

所有测试均基于 **交易执行结果** 判断是否通过，核心指标为 **成功率**（Success Rate）。

| 测试类型 | 判断依据 | 报告输出位置 |
|---------|---------|-------------|
| Foundry 压测 | `try/catch` 捕获 + 控制台输出 | 控制台 + `build/broadcast/` |
| Ape 压测 | `tx_receipt.status` + 异常捕获 | `reports/python/stress_*.json` |
| 混沌工程 | 基准 vs 故障 vs 恢复 三期对比 | `reports/chaos/chaos_report_*.json` |

### 1.2 合格标准

| 指标 | 合格阈值 | 说明 |
|-----|---------|------|
| 成功率 | ≥ 95% | 核心指标 |
| Gas 消耗 | 稳定在预期范围内 | 与基准值偏差 < 20% |
| TPS | 越高越好 | 用于评估系统吞吐能力 |
| 平均交易耗时 | 越低越好 | 超过 5s 可能存在问题 |

---

## 二、Foundry 压测（Solidity）

### 2.1 Gas 基准测试（GasBenchmark.s.sol）

#### 测试场景

测试 DEX 核心操作的 Gas 消耗基准：

| 操作 | 说明 | 典型 Gas 值范围 |
|-----|------|---------------|
| addLiquidity | 添加流动性 | 2,000,000 - 3,000,000 |
| swap | 代币兑换 | 15,000 - 25,000 |
| removeLiquidity | 移除流动性 | 40,000 - 60,000 |

#### 判断方式

通过 `gasleft()` 在交易前后的差值计算 Gas 消耗：

```solidity
uint256 gasBefore = gasleft();
router.swapExactTokensForTokens(...);
uint256 gasSwap = gasBefore - gasleft();
```

#### 结果分析

**查看输出**：
```
========== Gas Benchmark Report ==========
addLiquidity      : 2602656
swap              : 19978
removeLiquidity   : 46514
==========================================
```

**判断标准**：

| 场景 | 判断逻辑 | 结果解读 |
|-----|---------|---------|
| 所有操作成功执行 | 无 revert，脚本正常结束 | ✅ 通过 |
| Swap Gas 异常高 | > 30,000 gas | ⚠️ 合约可能存在问题 |
| AddLiquidity 失败 | revert 报错 | ❌ 失败，检查参数和授权 |

**分析要点**：
- Swap 操作 Gas 消耗低（~20k）→ 合约优化良好
- AddLiquidity 消耗高是正常的，因为涉及多步骤操作
- 与同类 DEX 对比，判断优化程度

---

### 2.2 单区块负载测试（SingleBlockLoad.s.sol）

#### 测试场景

测试单区块能容纳的最大交易数量，批量发送 50 笔 swap 交易。

#### 判断方式

使用 `try/catch` 捕获每笔交易结果，统计成功数：

```solidity
for (uint256 i = 0; i < BATCH_COUNT; i++) {
    try router.swapExactTokensForTokens(...) {
        successCount++;
    } catch {}
}
```

#### 结果分析

**查看输出**：
```
========== Single Block Load Report ==========
Batch count       : 50
Success count     : 50
Total gas used    : 1003897
Avg gas per tx    : 20077
Success rate      : 100 %
===============================================
```

**关键指标计算**：

| 指标 | 计算方式 | 合格标准 |
|-----|---------|---------|
| 成功率 | `(successCount * 100) / BATCH_COUNT` | ≥ 95% |
| 平均 Gas/笔 | `totalGas / BATCH_COUNT` | 稳定在 ~20,000 |
| 区块容量估算 | `30M / avgGas` | 可容纳交易数 |

**分析要点**：

| 场景 | 判断逻辑 | 结果解读 |
|-----|---------|---------|
| 成功率 100% | 所有 50 笔交易成功 | ✅ 通过 |
| 部分交易失败 | successCount < 47 | ⚠️ 存在问题，需排查 |
| Gas 超出预期 | avgGas > 25,000 | ⚠️ 单笔交易 Gas 异常 |

**容量估算示例**：
- 平均 Gas/笔 = 20,077
- 区块 Gas Limit = 30,000,000
- 可容纳交易数 = 30,000,000 / 20,077 ≈ 1494 笔

---

### 2.3 多用户并发测试（MultiUserConcurrent.s.sol）

#### 测试场景

测试多用户并发场景，5 个用户并发执行 swap 操作。

#### 判断方式

同样使用 `try/catch`，通过事件（Event）输出报告：

```solidity
for (uint256 i = 0; i < USER_NUM; i++) {
    try router.swapExactTokensForTokens(...) {
        successCount++;
    } catch {}
}
emit Report("SuccessRate", (successCount * 100) / USER_NUM);
```

#### 结果分析

**查看输出**：
```
========== Multi User Concurrent Report ==========
User count        : 5
Success count     : 5
Total gas used    : 1355692
Avg gas per tx    : 67784
Success rate      : 100 %
===================================================
```

**关键指标**：

| 指标 | 计算方式 | 合格标准 |
|-----|---------|---------|
| 成功率 | `(successCount * 100) / USER_NUM` | ≥ 95% |
| 并发处理能力 | 观察 Gas 波动 | 波动 < 20% |
| 总 Gas 消耗 | 累加所有交易 | 正常范围内 |

**分析要点**：

| 场景 | 判断逻辑 | 结果解读 |
|-----|---------|---------|
| 成功率 100% | 所有并发用户成功 | ✅ 通过 |
| 成功率下降 | < 95% | ⚠️ 并发处理存在问题 |
| Gas 波动大 | > 20% 偏差 | ⚠️ 资源竞争问题 |

---

## 三、Ape 压测（Python）

### 3.1 DEX Swap 并发压测（stress_dex_swap.py）

#### 测试场景

10 个并发用户执行 DEX Swap 操作，模拟真实并发场景。

#### 判断方式

通过 `tx_receipt` 和异常捕获判断：

```python
def user_swap(user_data):
    try:
        tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)
        tx_receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
        results.append({
            "gas_used": int(tx_receipt.gasUsed),
            "time_ms": tx_time * 1000
        })
    except Exception as e:
        errors.append({"error": str(e)})
```

#### 结果分析

**报告位置**：`reports/python/stress_dex_swap_*.json`

**报告结构**：
```json
{
  "timestamp": "2026-06-09T10:30:00",
  "test_name": "DEX Swap Stress Test",
  "config": {
    "concurrent_users": 10,
    "swap_amount": 1000000000000000000,
    "network": "http://127.0.0.1:8545"
  },
  "results": {
    "total_txs": 10,
    "success_txs": 10,
    "failed_txs": 0,
    "success_rate": 100.0,
    "total_time_ms": 1562.34,
    "avg_time_ms": 156.23,
    "avg_gas_used": 19978,
    "throughput_tps": 6.4
  },
  "detailed_results": [...],
  "errors": []
}
```

**关键指标**：

| 指标 | 计算方式 | 合格标准 | 说明 |
|-----|---------|---------|------|
| 成功率 | `success_txs / total_txs * 100` | ≥ 95% | 核心指标 |
| TPS | `success_txs / total_time` | 越高越好 | 系统吞吐量 |
| 平均耗时 | `sum(time_ms) / success_txs` | < 1000ms | 响应速度 |
| 平均 Gas | `sum(gas_used) / success_txs` | ~20,000 | 稳定性 |

**判断标准**：

| 场景 | 判断逻辑 | 结果解读 |
|-----|---------|---------|
| 成功率 100% | success_rate = 100 | ✅ 通过 |
| 成功率 < 95% | 存在失败交易 | ⚠️ 需要排查错误日志 |
| TPS 异常低 | < 预期值的 50% | ⚠️ 系统性能问题 |
| errors 有内容 | 存在错误记录 | ❌ 失败，需分析错误原因 |

---

### 3.2 清算业务压测（stress_liquidation.py）

#### 测试场景

清算业务压测，支持长时循环模式，用于验证长期稳定性。

#### 判断方式

与 DEX Swap 类似，支持两种模式：

```python
# 短时基准压测
LONG_RUN_STRESS = False

# 长时循环压测
LONG_RUN_STRESS = True
```

#### 结果分析

**报告位置**：`reports/python/stress_liquidation_*.json`

**报告结构**：
```json
{
  "timestamp": "2026-06-09T10:30:00",
  "test_name": "Liquidation Stress Test",
  "config": {
    "concurrent_users": 10,
    "network": "http://127.0.0.1:8545"
  },
  "results": {
    "total_txs": 10,
    "success_txs": 10,
    "failed_txs": 0,
    "success_rate": 100.0,
    "throughput_tps": 8.5
  },
  "detailed_results": [...],
  "errors": []
}
```

**长时压测分析**：

| 观察指标 | 正常表现 | 异常表现 |
|---------|---------|---------|
| 成功率稳定性 | 各轮均 ≥ 95% | 成功率逐渐下降 |
| TPS 稳定性 | 各轮波动 < 10% | TPS 持续下降 |
| 错误累积 | errors 为空或极少 | errors 逐渐增加 |

**判断标准**：

| 场景 | 判断逻辑 | 结果解读 |
|-----|---------|---------|
| 单轮成功率 | ≥ 95% | ✅ 通过 |
| 长时稳定性 | 各轮成功率稳定 | ✅ 通过 |
| 长时成功率下降 | 成功率持续下降 | ⚠️ 内存泄漏或状态问题 |

---

## 四、混沌工程测试

### 4.1 核心测试流程

所有混沌测试遵循 **三期对比法**：

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   基准期    │ →   │   故障期    │ →   │   恢复期    │
│  Baseline   │     │   Failure   │     │  Recovery   │
│  正常条件   │     │ 注入故障后   │     │  恢复后验证  │
└─────────────┘     └─────────────┘     └─────────────┘
```

### 4.2 完整版（chaos_engine.py）

#### 测试场景

| 场景 | 故障注入方式 | 需要 root | 说明 |
|-----|-------------|----------|------|
| network_delay | 网络延迟 200ms | ✅ | 模拟网络延迟 |
| packet_loss | 网络丢包 10% | ✅ | 模拟网络不稳定 |
| node_failure | 节点停机 5s | ❌ | 模拟节点故障 |
| resource_limit | CPU 限制 50% | ✅ | 模拟资源限制 |

#### 判断方式

```python
def run_chaos_scenario(self, scenario_name):
    # 基准测试
    baseline_result = self.run_performance_test()
    
    # 注入故障
    success = scenarios[scenario_name]["inject"]()
    
    # 故障下测试
    failure_result = self.run_performance_test()
    
    # 恢复后测试
    recovery_result = self.run_performance_test()
```

#### 结果分析

**报告位置**：`reports/chaos/chaos_report_*.json`

**报告结构**：
```json
{
  "scenario": "network_delay",
  "description": "网络延迟测试",
  "timestamp": "2026-06-09T10:30:00",
  "baseline": {
    "success_count": 5,
    "fail_count": 0,
    "return_code": 0
  },
  "failure": {
    "success_count": 4,
    "fail_count": 1,
    "return_code": 0
  },
  "recovery": {
    "success_count": 5,
    "fail_count": 0,
    "return_code": 0
  },
  "impact": {
    "success_rate_drop_pct": 20.0,
    "failures_introduced": 1
  }
}
```

**关键指标**：

| 指标 | 计算方式 | 合格标准 |
|-----|---------|---------|
| 成功率下降 | `(baseline - failure) / baseline * 100` | ≤ 20% |
| 新增失败数 | `failure_fail_count - baseline_fail_count` | 越少越好 |
| 恢复成功率 | 接近基准水平 | ≥ 90% 基准值 |

**判断标准**：

| 场景 | 判断逻辑 | 结果解读 |
|-----|---------|---------|
| 成功率下降 ≤ 20% | 故障对系统影响可控 | ✅ 通过 |
| 成功率下降 > 20% | 故障影响较大 | ⚠️ 需要优化容错机制 |
| 恢复后成功率下降 | recovery < 90% baseline | ⚠️ 恢复能力存在问题 |
| failures_introduced = 0 | 无新增失败 | ✅ 容错能力优秀 |

---

### 4.3 简化版（chaos_simple.py）

#### 测试场景（无需 root）

| 场景 | 模拟方式 | 说明 |
|-----|---------|------|
| transaction_failure | 设置失败率 | 模拟交易失败 |
| high_latency | time.sleep() | 模拟高延迟 |
| slow_node | 增加请求间隔 | 模拟节点响应变慢 |

#### 判断方式

```python
def run_chaos_test(self, scenario):
    # 基准
    baseline = self.run_pressure_test()
    
    # 应用混沌条件
    if scenario == "transaction_failure":
        failure_rate = self.inject_transaction_failure(0.1)
    
    # 混沌条件下测试
    chaos_result = self.run_pressure_test()
    
    # 恢复后测试
    recovery = self.run_pressure_test()
```

#### 结果分析

**报告结构**：
```json
{
  "scenario": "high_latency",
  "baseline": {
    "success_count": 5,
    "fail_count": 0
  },
  "chaos": {
    "success_count": 4,
    "fail_count": 1
  },
  "recovery": {
    "success_count": 5,
    "fail_count": 0
  },
  "impact": {
    "success_rate_drop_pct": 20.0,
    "failures_introduced": 1
  }
}
```

**分析要点**：

| 场景 | 判断逻辑 | 结果解读 |
|-----|---------|---------|
| returncode = 0 | Forge 脚本执行成功 | ✅ 通过 |
| 成功率下降 | chaos < baseline | ⚠️ 存在影响 |
| 恢复成功 | recovery 接近 baseline | ✅ 恢复能力正常 |

---

## 五、常见问题诊断

### 5.1 失败类型与排查

| 失败类型 | 错误表现 | 原因 | 排查方向 |
|---------|---------|------|---------|
| Gas 不足 | revert: out of gas | Gas Limit 设置过小 | 增大 `gas` 参数 |
| 授权失败 | revert: approval failed | MyERC20 不允许无限授权 | 使用 `type(uint256).max - 1` |
| 余额不足 | revert: insufficient funds | 测试账户 ETH/代币不足 | 铸造更多代币或转账 ETH |
| 链 ID 不匹配 | chain id mismatch | anvil 链 ID 错误 | 使用 `--chain-id 31337` |
| 节点连接失败 | Connection refused | anvil 未启动或端口错误 | 确认 anvil 运行在 8545 端口 |

### 5.2 性能问题诊断

| 问题 | 表现 | 原因 | 解决方案 |
|-----|------|------|---------|
| TPS 低 | 实际 TPS < 预期 50% | 网络延迟或节点性能 | 检查网络和硬件 |
| Gas 波动大 | avgGas 偏差 > 30% | 交易复杂度不一致 | 检查合约逻辑 |
| 成功率下降 | < 95% | 并发冲突或资源争用 | 优化合约和测试场景 |
| 超时 | 交易长时间 pending | Gas Price 过低或网络拥堵 | 提高 Gas Price |

---

## 六、快速分析模板

### 6.1 Foundry 压测

```bash
# 1. 检查成功率
grep "Success rate" output.log

# 2. 检查 Gas 消耗
grep "gas used" output.log

# 3. 验证报告
cat broadcast/xxx.s.sol/1/run-latest.json | jq '.transactions | length'
```

### 6.2 Ape 压测

```bash
# 1. 检查成功率
cat reports/python/stress_dex_swap_*.json | jq '.results.success_rate'

# 2. 检查 TPS
cat reports/python/stress_dex_swap_*.json | jq '.results.throughput_tps'

# 3. 检查错误
cat reports/python/stress_dex_swap_*.json | jq '.errors | length'
```

### 6.3 混沌工程

```bash
# 1. 检查各场景影响
cat reports/chaos/chaos_report_*.json | jq '.results[].impact.success_rate_drop_pct'

# 2. 检查恢复情况
cat reports/chaos/chaos_report_*.json | jq '.results[].recovery.success_count'

# 3. 检查失败数
cat reports/chaos/chaos_report_*.json | jq '[.results[].impact.failures_introduced] | add'
```

---

## 七、测试结果记录模板

| 测试类型 | 执行时间 | 成功率 | 关键指标 | 状态 | 备注 |
|----------|----------|--------|----------|------|------|
| Gas基准测试 | YYYY-MM-DD | 100% | swap: 19,978 gas | ✅ | 正常 |
| 单区块负载 | YYYY-MM-DD | 100% | 50笔/块, ~1500笔/区块容量 | ✅ | 正常 |
| 多用户并发 | YYYY-MM-DD | 100% | 5用户并发 | ✅ | 正常 |
| DEX Swap压测 | YYYY-MM-DD | 100% | TPS: 6.4 | ✅ | 正常 |
| 网络延迟测试 | YYYY-MM-DD | 80% | 成功率下降: 20% | ⚠️ | 可接受 |
| 节点故障测试 | YYYY-MM-DD | 100% | 恢复成功 | ✅ | 正常 |

---

## 八、附录：指标计算公式

### 8.1 成功率

```
成功率 = (成功交易数 / 总交易数) × 100%
```

### 8.2 TPS（每秒交易数）

```
TPS = 成功交易数 / 总执行时间(秒)
```

### 8.3 混沌测试影响度

```
成功率下降 = (基准成功率 - 故障成功率) / 基准成功率 × 100%
```

### 8.4 区块容量估算

```
可容纳交易数 = 区块 Gas Limit / 单笔交易平均 Gas
```

## 九、分布式压测
- locust 压测
- jmeter 压测


---

**文档结束**
