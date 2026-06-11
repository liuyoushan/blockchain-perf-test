#!/bin/bash

echo "========== Multi User Concurrent Test =========="
echo ""

# 清理旧的编译缓存
forge clean

# 执行脚本
forge script src/MultiUserConcurrent.s.sol --rpc-url http://127.0.0.1:8545 --broadcast

echo ""
echo "========== Parsing Results =========="
echo ""

# 解析广播日志获取交易信息
BROADCAST_FILE="broadcast/MultiUserConcurrent.s.sol/1/run-latest.json"

if [ -f "$BROADCAST_FILE" ]; then
    echo "=== Report from broadcast file ==="
    echo "User Count: 5"
    
    # 使用 jq 解析 JSON
    if command -v jq &> /dev/null; then
        # 获取最后5个交易（用户交换交易）
        # 计算总交易数
        TOTAL_TX=$(jq '.receipts | length' $BROADCAST_FILE)
        START_INDEX=$(( TOTAL_TX - 5 ))
        
        # 获取最后5个交易的状态和gasUsed
        # 使用 fromjson 处理十六进制
        SUCCESS_COUNT=$(jq "[.receipts[$START_INDEX:][] | .status == \"0x1\"] | map(select(. == true)) | length" $BROADCAST_FILE)
        echo "Success Count: $SUCCESS_COUNT"
        
        # 计算成功率
        SUCCESS_RATE=$(( (SUCCESS_COUNT * 100) / 5 ))
        echo "Success Rate: ${SUCCESS_RATE}%"
        
        # 获取最后5个交易的总 Gas 消耗
        TOTAL_GAS=$(jq ".receipts[$START_INDEX:][] | .gasUsed" $BROADCAST_FILE | tr -d '"' | awk '{sum += strtonum("0x"$1)} END {print sum}')
        echo "Total Gas Used: $TOTAL_GAS"
        
        if [ "$SUCCESS_COUNT" -gt 0 ] && [ "$TOTAL_GAS" -gt 0 ]; then
            AVG_GAS=$(( TOTAL_GAS / SUCCESS_COUNT ))
            echo "Avg Gas per Tx: $AVG_GAS"
        fi
    else
        echo "jq not found, cannot parse results"
    fi
    
    echo ""
    echo "=== End Report ==="
else
    echo "Broadcast file not found!"
fi
