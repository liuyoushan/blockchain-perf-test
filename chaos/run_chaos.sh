#!/bin/bash
# 混沌工程测试启动脚本

echo "=============================================="
echo "        区块链混沌工程测试套件"
echo "=============================================="

# 检查 anvil 是否运行
if ! pgrep anvil > /dev/null; then
    echo "⚠️  未检测到 anvil 节点，正在启动..."
    anvil --host 127.0.0.1 --port 8545 --block-time 1 > /tmp/anvil.log 2>&1 &
    sleep 5
    echo "✅ anvil 节点已启动"
fi

# 选择测试模式
echo ""
echo "请选择测试模式:"
echo "1. 完整版 (需要root权限，支持网络级故障注入)"
echo "2. 简化版 (无需root权限，基础稳定性测试)"
read -p "输入选择 (1/2): " choice

case $choice in
    1)
        echo "🚀 启动完整版混沌测试..."
        python3 /home/liuyoushan/blockchain-perf-test/chaos/chaos_engine.py
        ;;
    2)
        echo "🚀 启动简化版混沌测试..."
        python3 /home/liuyoushan/blockchain-perf-test/chaos/chaos_simple.py
        ;;
    *)
        echo "❌ 无效选择"
        exit 1
        ;;
esac

echo ""
echo "=============================================="
echo "          混沌测试完成！"
echo "=============================================="
echo "报告位置: /home/liuyoushan/blockchain-perf-test/chaos/reports/"
