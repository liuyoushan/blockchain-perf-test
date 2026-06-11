# 轻量级性能测试标准操作流程 (SOP)

## 文档版本
- 版本：v1.0
- 日期：2026-06-09
- 适用范围：ape-demo/perf 轻量级性能测试框架
- 特点：无需 Docker，纯 Python + Foundry 实现

---

## 目录
1. [环境准备](#一环境准备)
2. [启动测试节点](#二启动测试节点)
3. [启动监控仪表盘](#三启动监控仪表盘)
4. [执行压测脚本](#四执行压测脚本)
5. [查看监控结果](#五查看监控结果)
6. [结果分析](#六结果分析)
7. [常用命令速查](#七常用命令速查)
8. [问题排查](#八问题排查)

---

## 一、环境准备

### 1.1 前置依赖

| 依赖 | 版本要求 | 安装方式 |
|------|----------|----------|
| Foundry | >= 0.2.0 | `curl -L https://foundry.paradigm.xyz | bash` |
| Python | >= 3.8 | 系统自带或官网安装 |
| Flask | >= 2.0 | `pip install flask` |
| jq | >= 1.6 | `sudo apt install jq` (可选) |

### 1.2 验证依赖

```bash
# 验证 Foundry
forge --version

# 验证 Python
python3 --version

# 验证 Flask
python3 -c "import flask; print('Flask OK')"
```

---

## 二、启动测试节点

### 2.1 启动 Anvil 测试节点

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

### 2.2 验证节点连接

```bash
# 验证节点运行状态
curl -s http://127.0.0.1:8545 -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"net_version","id":1}'

# 预期输出：{"jsonrpc":"2.0","id":1,"result":"31337"}
```

---

## 三、启动监控仪表盘

### 3.1 启动监控服务

打开 **终端2**，执行：

```bash
# 进入 perf 目录
cd /home/liuyoushan/ape-demo/perf

# 启动轻量级监控仪表盘
python3 monitoring/simple_dashboard.py

# 预期输出：
#  * Serving Flask app 'simple_dashboard'
#  * Running on http://127.0.0.1:8001
```

### 3.2 访问监控仪表盘

打开浏览器访问：**http://localhost:8001/**

仪表盘功能：
- 📊 交易文件总数统计
- ⛽ 总 Gas 消耗统计
- 📋 广播报告列表
- 🔄 自动刷新数据

---

## 四、执行压测脚本

### 4.1 执行前准备

打开 **终端3**，执行：

```bash
# 进入 perf 目录
cd /home/liuyoushan/ape-demo/perf

# 设置测试私钥（Anvil 默认测试账户）
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff943c21ee9409cbe98727d6c8d49c89426
```

### 4.2 执行 Gas 基准测试

```bash
# 执行命令
forge script src/GasBenchmark.s.sol --rpc-url http://127.0.0.1:8545 --broadcast -v

# 预期输出：
# ========== Gas Benchmark Report ==========
#   addLiquidity      : 2602656
#   swap              : 19978
#   removeLiquidity   : 46514
#   ==========================================
```

### 4.3 执行单区块负载测试

```bash
# 执行命令
forge script src/SingleBlockLoad.s.sol --rpc-url http://127.0.0.1:8545 --broadcast -v

# 预期输出：
# ========== Single Block Load Report ==========
#   Batch count       : 50
#   Success count     : 50
#   Total gas used    : 1003897
#   Avg gas per tx    : 20077
#   Success rate      : 100 %
#   ================================================
```

### 4.4 执行多用户并发测试

```bash
# 执行命令
forge script src/MultiUserConcurrent.s.sol --rpc-url http://127.0.0.1:8545 --broadcast -v

# 预期输出：
# ========== Multi User Concurrent Report ==========
#   User count        : 20
#   Success count     : 20
#   Total gas used    : 1355692
#   Avg gas per tx    : 67784
#   Success rate      : 100 %
#   ====================================================
```

---

## 五、查看监控结果

### 5.1 浏览器查看

访问 **http://localhost:8001/**，实时查看：

| 指标 | 说明 |
|------|------|
| 交易文件总数 | 广播目录中 JSON 文件数量 |
| 总 Gas 消耗 | 所有交易的 Gas 消耗总和 |
| 广播报告列表 | 各测试脚本生成的报告 |

### 5.2 命令行查看指标

```bash
# 查看 Prometheus 格式指标
curl http://localhost:8000/metrics

# 预期输出：
# # HELP eth_transaction_count_total Total transactions
# # TYPE eth_transaction_count_total gauge
# eth_transaction_count_total 25
# 
# # HELP eth_total_gas_used Total gas used
# # TYPE eth_total_gas_used gauge
# eth_total_gas_used 10534287
```

---

## 六、结果分析

### 6.1 实时日志分析

脚本执行时直接观察终端输出，每个脚本内置报告：

```bash
# 示例输出格式
========== Gas Benchmark Report ==========
  addLiquidity      : 2602656
  swap              : 19978
  removeLiquidity   : 46514
  ==========================================
```

### 6.2 广播报告分析

Foundry 自动生成 JSON 报告到 `broadcast/` 目录：

```bash
# 查看报告目录
ls -la broadcast/

# 分析 Gas 基准测试报告
cat broadcast/GasBenchmark.s.sol/1/run-latest.json | jq '{
  chainId: .chainId,
  txCount: (.transactions | length),
  transactions: [.transactions[] | {
    contract: .contractName,
    function: .function,
    gasUsed: .gasUsed
  }]
}'
```

### 6.3 链上验证

使用 `cast` 工具验证链上状态：

```bash
# 查看交易详情
cast tx 0x79748f32a62ecbfcebcd26a44653df1deedc2c735cc38d44418717c8f5da60ca

# 查看合约状态
cast call <Router地址> "getReserves()" --rpc-url http://127.0.0.1:8545

# 查看区块信息
cast block 19500002
```

### 6.4 结果记录模板

| 测试类型 | 执行时间 | 成功率 | 关键指标 | 状态 |
|----------|----------|--------|----------|------|
| Gas基准测试 | 2026-06-09 | 100% | swap: 19,978 gas | ✅ |
| 单区块负载 | 2026-06-09 | 100% | 50笔/块 | ✅ |
| 多用户并发 | 2026-06-09 | 100% | 20用户 | ✅ |

---

## 七、常用命令速查

| 操作 | 命令 |
|------|------|
| 启动节点 | `anvil --host 127.0.0.1 --port 8545` |
| 设置私钥 | `export PRIVATE_KEY=0xac...` |
| 启动监控 | `python3 monitoring/simple_dashboard.py` |
| Gas基准测试 | `forge script src/GasBenchmark.s.sol --broadcast -v` |
| 单区块负载 | `forge script src/SingleBlockLoad.s.sol --broadcast -v` |
| 多用户并发 | `forge script src/MultiUserConcurrent.s.sol --broadcast -v` |
| 查看交易 | `cast tx <哈希>` |
| 查看区块 | `cast block <区块号>` |
| 分析报告 | `cat run-latest.json \| jq .` |

---

## 八、问题排查

### 8.1 常见错误

| 错误类型 | 错误信息 | 解决方案 |
|----------|----------|----------|
| 连接失败 | `Connection refused` | 检查 Anvil 是否启动 |
| 余额不足 | `Insufficient funds` | 使用正确的测试私钥 |
| 授权失败 | `Infinite approval not allowed` | 使用 `type(uint256).max - 1` |
| 编译错误 | `Stack too deep` | 在 `foundry.toml` 中添加 `via_ir = true` |

### 8.2 调试技巧

```bash
# 启用详细日志
forge script xxx.s.sol --broadcast -vvvv

# 模拟执行（不广播）
forge script xxx.s.sol --simulate

# 查看合约源码
forge inspect <合约名> code

# 调试交易
cast send <地址> "<方法名>()" --dry-run
```

---

## 附录：一键执行脚本

```bash
#!/bin/bash
# run_all_tests.sh

cd /home/liuyoushan/ape-demo/perf
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff943c21ee9409cbe98727d6c8d49c89426

echo "=== 开始执行 Gas 基准测试 ==="
forge script src/GasBenchmark.s.sol --rpc-url http://127.0.0.1:8545 --broadcast -v

echo "=== 开始执行单区块负载测试 ==="
forge script src/SingleBlockLoad.s.sol --rpc-url http://127.0.0.1:8545 --broadcast -v

echo "=== 开始执行多用户并发测试 ==="
forge script src/MultiUserConcurrent.s.sol --rpc-url http://127.0.0.1:8545 --broadcast -v

echo "=== 所有测试执行完成 ==="
echo "请访问 http://localhost:8001/ 查看监控结果"
```

---

**文档结束**

---

> 📌 **提示**：此文档为轻量级方案专用，如需使用完整的 Prometheus + Grafana 方案，请参考原 `SOP.md` 文档（需先修复 Docker 环境）。
