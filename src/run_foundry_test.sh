#!/bin/bash
# Foundry 压测运行脚本 - 自动执行测试并生成报告

set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

# 默认使用本地节点，可通过环境变量覆盖
RPC_URL="${RPC_URL:-http://127.0.0.1:8545}"

echo "🚀 开始执行 Foundry 压测..."
echo "� 目标节点: $RPC_URL"

echo "🔗 验证节点连接..."
if ! curl -s "$RPC_URL" -X POST -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"net_version","id":1}' | grep -q "result"; then
    echo "❌ 节点连接失败"
    exit 1
fi

echo "✅ 节点连接成功"

cd "$PROJECT_ROOT"

echo "📦 编译合约..."
forge build 2>&1 | tail -20

echo "📦 执行 MultiUserConcurrent 测试..."
forge script src/MultiUserConcurrent.s.sol --rpc-url "$RPC_URL" --broadcast -vvv

echo "📦 执行 GasBenchmark 测试..."
forge script src/GasBenchmark.s.sol --rpc-url "$RPC_URL" --broadcast -vvv

echo "📦 执行 SingleBlockLoad 测试..."
forge script src/SingleBlockLoad.s.sol --rpc-url "$RPC_URL" --broadcast -vvv

echo "📊 生成报告..."
python3 "$PROJECT_ROOT/tools/generate_foundry_report.py"

echo "✅ Foundry 压测完成！报告已保存到 reports/foundry/"
