# Performance Test Suite

企业级区块链性能测试框架，所有压测相关代码集中在一个目录下。

## 目录结构

```
ape-demo/
├── contracts/              # 业务合约（唯一可信源）
├── tests/                 # 功能测试（单元/集成）
├── scripts/               # 业务脚本（部署等）
└── perf/                  # 压测统一目录（所有压测相关）
    ├── foundry.toml       # Foundry 配置
    ├── src/               # 仅压测专用脚本（无业务合约副本）
    │   ├── GasBenchmark.s.sol
    │   ├── SingleBlockLoad.s.sol
    │   └── MultiUserConcurrent.s.sol
    │
    ├── foundry.toml       # src = "../contracts" 指向根目录可信任合约
    ├── ape/               # Ape Python 压测
    │   ├── stress_dex_swap.py
    │   └── stress_liquidation.py
    ├── chaos/             # 混沌工程测试
    │   ├── chaos_engine.py      # 完整版混沌引擎（需root）
    │   ├── chaos_simple.py      # 简化版混沌引擎
    │   ├── run_chaos.sh         # 启动脚本
    │   └── reports/             # 混沌测试报告
    ├── monitoring/        # 监控配置（Prometheus + Grafana）
    │   ├── prometheus.yml
    │   ├── docker-compose.yml
    │   └── grafana/
    ├── reports/           # 压测报告输出
    └── README.md
```

## 执行方式

### 1. 启动本地测试节点

```bash
# 终端1：启动 anvil
anvil
```

### 2. Foundry 压测（Solidity）

```bash
cd perf

# 加载环境变量（.env 文件方式）
source .env

# Gas 基准测试
forge script src/GasBenchmark.s.sol --rpc-url http://127.0.0.1:8545 --broadcast

# 单区块负载压测
forge script src/SingleBlockLoad.s.sol --rpc-url http://127.0.0.1:8545 --broadcast

# 多用户并发压测
forge script src/MultiUserConcurrent.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

**.env 文件示例：**
```bash
# .env 文件内容
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

### 3. Ape 压测（Python）

```bash
# DEX Swap 并发压测
ape run perf/ape/stress_dex_swap.py

# 清算业务压测
ape run perf/ape/stress_liquidation.py
```

### 4. 启动监控（Prometheus + Grafana）

```bash
cd perf/monitoring
docker compose up -d

停止监控
docker compose down

# 访问
# Grafana: http://localhost:3000 (admin/admin)
# Prometheus: http://localhost:9090
```

### 5. 混沌工程测试

混沌工程用于验证系统在极端条件下的稳定性和容错能力。

```bash
cd perf

# 方式一：使用启动脚本（推荐）
./chaos/run_chaos.sh

# 方式二：直接运行
# 完整版（需要root权限，支持网络级故障注入）
sudo python3 chaos/chaos_engine.py

# 简化版（无需root权限，基础稳定性测试）
python3 chaos/chaos_simple.py
```

**混沌测试场景：**

| 场景 | 说明 | 需要root |
|------|------|----------|
| network_delay | 网络延迟测试 | ✅ |
| packet_loss | 网络丢包测试 | ✅ |
| node_failure | 节点故障测试 | ❌ |
| resource_limit | 资源限制测试 | ✅ |
| transaction_failure | 交易失败注入 | ❌ |
| high_latency | 高延迟模拟 | ❌ |

## 实际执行结果

### Gas 基准测试 ✅

| 操作              | Gas 消耗    | 说明       |
| --------------- | --------- | -------- |
| addLiquidity    | 2,602,656 | 添加流动性操作  |
| swap            | 19,978    | 兑换操作（最优） |
| removeLiquidity | 46,514    | 移除流动性操作  |

**分析**：Swap 操作 Gas 消耗非常低（\~20k），说明合约优化良好。

### 单区块负载压测 ✅

| 指标       | 结果        |
| -------- | --------- |
| 批量交易数    | 50 笔      |
| 成功数      | 50 笔      |
| 成功率      | 100%      |
| 总 Gas 消耗 | 1,003,897 |
| 平均 Gas/笔 | 20,077    |

**分析**：单区块可稳定处理 50+ 笔交易，按 30M gas limit 估算可容纳 \~1500 笔 swap 交易。

### 多用户并发压测 ✅

| 指标       | 结果        |
| -------- | --------- |
| 用户数      | 20        |
| 成功数      | 20        |
| 成功率      | 100%      |
| 总 Gas 消耗 | 1,355,692 |
| 平均 Gas/笔 | 67,784    |

**分析**：20 用户并发全部成功，并发场景下 Gas 略有上升（约 3.4x），属正常范围。

### Ape Python 压测 ⚠️

| 脚本                     | 状态   | 备注             |
| ---------------------- | ---- | -------------- |
| stress\_dex\_swap.py   | 配置问题 | 链ID不匹配，需调整网络配置 |
| stress\_liquidation.py | 框架就绪 | 等待清算合约实现       |

**问题说明**：当前 anvil 节点链ID为 1（主网），与 Ape 本地配置不匹配，需调整网络配置或重启 anvil 使用测试链ID。

### 混沌工程测试 🌀

混沌工程测试用于验证系统在极端条件下的稳定性和容错能力。

**测试场景说明：**

| 场景 | 描述 | 验证目标 |
|------|------|----------|
| 网络延迟 | 注入 200ms 网络延迟 | 验证系统在高延迟下的响应能力 |
| 网络丢包 | 注入 10% 丢包率 | 验证系统的容错和重试机制 |
| 节点故障 | 模拟节点崩溃后重启 | 验证系统的恢复能力 |
| 资源限制 | 限制 CPU 和内存 | 验证系统在资源受限下的表现 |

**测试报告示例：**

```json
{
  "scenario": "network_delay",
  "impact": {
    "success_rate_drop_pct": 15.5,
    "failures_introduced": 3
  },
  "baseline": {"success_count": 50, "fail_count": 0},
  "chaos": {"success_count": 42, "fail_count": 8},
  "recovery": {"success_count": 50, "fail_count": 0}
}
```

**分析指标：**
- 成功率下降百分比：衡量系统对故障的敏感度
- 新增失败数：故障引入的具体影响
- 恢复后状态：验证系统是否能够自动恢复

## 压测脚本说明

### GasBenchmark.s.sol

测试 DEX 核心操作的 Gas 消耗基准：

- `addLiquidity` - 添加流动性
- `swapExactTokensForTokens` - 代币兑换
- `removeLiquidity` - 移除流动性

### SingleBlockLoad.s.sol

测试单区块能容纳的最大交易数量：

- 批量发送 50 笔 swap 交易
- 统计总 Gas 消耗和成功率

### MultiUserConcurrent.s.sol

测试多用户并发场景：

- 创建 20 个独立用户
- 每个用户执行 swap 操作
- 模拟真实并发场景

## 注意事项

1. **MyERC20 授权限制**：合约不允许无限授权（`type(uint256).max`），需使用 `type(uint256).max - 1`
2. **测试余额**：确保测试账户有足够 ETH 支付 Gas
3. **合约同步**：如修改 `contracts/`，需同步更新 `perf/src/contracts/`

