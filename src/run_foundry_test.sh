#!/bin/bash
# Foundry 压测运行脚本 - 自动执行测试并生成报告

set -e

echo "🚀 开始执行 Foundry 压测..."

# 执行所有 Foundry 脚本
echo "📦 执行 MultiUserConcurrent 测试..."
forge script MultiUserConcurrent.s.sol --rpc-url http://127.0.0.1:8545 --broadcast -vvv 2>&1 | tail -10

echo "📦 执行 GasBenchmark 测试..."
forge script GasBenchmark.s.sol --rpc-url http://127.0.0.1:8545 --broadcast -vvv 2>&1 | tail -10

echo "📦 执行 SingleBlockLoad 测试..."
forge script SingleBlockLoad.s.sol --rpc-url http://127.0.0.1:8545 --broadcast -vvv 2>&1 | tail -10

echo "📊 生成报告..."
python3 tools/generate_foundry_report.py

echo "✅ Foundry 压测完成！报告已保存到 reports/foundry/"
