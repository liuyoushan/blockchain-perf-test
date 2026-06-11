# Prometheus + Grafana 全量监控标准操作流程 (SOP)

## 文档版本

- 版本：v2.0
- 日期：2026-06-09
- 适用范围：ape-demo/perf Prometheus + Grafana 全量监控方案
- 特点：企业级监控体系，完整的指标采集和可视化

***

## 目录

1. [监控架构概述](#一监控架构概述)
2. [环境准备](#二环境准备)
3. [启动监控服务](#三启动监控服务)
4. [配置 Prometheus](#四配置-prometheus)
5. [配置 Grafana](#五配置-grafana)
6. [创建监控仪表盘](#六创建监控仪表盘)
7. [监控指标体系](#七监控指标体系)
8. [告警配置](#八告警配置)
9. [常用操作](#九常用操作)
10. [问题排查](#十问题排查)

***

## 一、监控架构概述

### 1.1 架构图

```
┌─────────────────────────────────────────────────────────────┐
│                   Prometheus + Grafana 监控架构             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │  Anvil节点   │    │   Exporter   │    │  Prometheus  │  │
│  │              │───→│              │───→│              │  │
│  │  区块数据    │    │  指标导出    │    │  数据存储    │  │
│  │  交易数据    │    │  格式转换    │    │  查询引擎    │  │
│  └──────────────┘    └──────────────┘    └──────┬───────┘  │
│                                                   │          │
│                                                   ▼          │
│                                          ┌──────────────┐   │
│                                          │   Grafana    │   │
│                                          │              │   │
│                                          │  可视化展示  │   │
│                                          │  告警通知    │   │
│                                          └──────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 组件说明

| 组件                 | 端口   | 职责                          |
| ------------------ | ---- | --------------------------- |
| **Anvil**          | 8545 | 本地测试节点，产生交易和区块数据            |
| **Chain Exporter** | 9102 | 从广播报告中提取指标，暴露 Prometheus 格式 |
| **Prometheus**     | 9090 | 指标采集、存储和查询                  |
| **Grafana**        | 3000 | 可视化仪表盘和告警                   |

### 1.3 数据流向

```
压测脚本 → Anvil节点 → 广播报告 → Exporter → Prometheus → Grafana
    │           │           │           │           │          │
    └───────────┴───────────┴───────────┴───────────┴──────────┘
                            数据采集和展示全链路
```

***

## 二、环境准备

### 2.1 前置依赖

| 依赖             | 版本要求    | 安装方式                                      |
| -------------- | ------- | ----------------------------------------- |
| Docker         | >= 20.0 | `curl -fsSL https://get.docker.com \| sh` |
| Docker Compose | >= 2.0  | `sudo apt install docker-compose`         |
| Python         | >= 3.8  | 系统自带                                      |
| Flask          | >= 2.0  | `pip install flask`                       |

### 2.2 验证依赖

```bash
# 验证 Docker
docker --version

# 验证 Docker Compose
docker-compose --version

# 验证 Python
python3 --version

# 验证 Flask
python3 -c "import flask; print('Flask OK')"
```

### 2.3 检查端口占用

```bash
# 检查端口是否被占用
ss -tlnp | grep -E ':(3000|9090|9100|8545)'

# 如果端口被占用，可以停止相关服务
# 或者修改配置文件中的端口
```

***

## 三、启动监控服务

### 3.1 启动 Anvil 测试节点

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

### 3.2 启动 Chain Exporter

打开 **终端2**，执行：

```bash
# 进入 monitoring 目录
cd /home/liuyoushan/ape-demo/perf/monitoring

# 启动 Exporter
python3 chain_exporter.py

# 预期输出：
#  * Serving Flask app 'chain_exporter'
#  * Running on http://0.0.0.0:9102
```

### 3.3 验证 Exporter

```bash
# 验证指标端点
curl http://localhost:9102/metrics

# 预期输出：
# # HELP eth_transaction_count_total Total transactions
# # TYPE eth_transaction_count_total gauge
# eth_transaction_count_total 0
# 
# # HELP eth_total_gas_used Total gas used
# # TYPE eth_total_gas_used gauge
# eth_total_gas_used 0
```

### 3.4 启动 Prometheus 和 Grafana

打开 **终端3**，执行：

```bash
# 进入 monitoring 目录
cd /home/liuyoushan/ape-demo/perf/monitoring

# 启动 Docker 容器
docker compose up -d

# 预期输出：
# Creating network "monitoring_default" with the default driver
# Creating prometheus ... done
# Creating grafana    ... done
```

### 3.5 验证服务状态

```bash
# 检查容器状态
docker ps

# 预期输出：
# CONTAINER ID   IMAGE                  COMMAND                  STATUS          PORTS
# xxxxxxxxxx     grafana/grafana        "/run.sh"                Up 10 seconds   0.0.0.0:3000->3000/tcp
# xxxxxxxxxx     prom/prometheus        "/bin/prometheus --…"    Up 10 seconds   0.0.0.0:9090->9090/tcp

# 验证 Prometheus
curl http://localhost:9090/api/v1/targets

# 验证 Grafana
curl http://localhost:3000/api/health
```

***

## 四、配置 Prometheus

### 4.1 配置文件说明

配置文件位置：`/home/liuyoushan/ape-demo/perf/monitoring/prometheus.yml`

```yaml
# prometheus.yml
global:
  scrape_interval: 5s      # 每 5 秒抓取一次指标
  evaluation_interval: 5s  # 每 5 秒评估一次规则

scrape_configs:
  - job_name: 'chain-exporter'
    static_configs:
      - targets: ['chain-exporter:9100']  # Exporter 地址
    metrics_path: /metrics
```

### 4.2 修改配置（如需要）

```bash
# 编辑配置文件
vi /home/liuyoushan/ape-demo/perf/monitoring/prometheus.yml

# 修改后重启 Prometheus
docker restart prometheus
```

### 4.3 验证配置

```bash
# 访问 Prometheus UI
# 浏览器打开：http://localhost:9090

# 检查 Targets 状态
# 点击 Status → Targets
# 确认 chain-exporter 状态为 UP
```

### 4.4 测试查询

在 Prometheus UI 中执行查询：

```promql
# 查询交易总数
eth_transaction_count_total

# 查询 Gas 消耗
eth_total_gas_used

# 计算最近 5 分钟的 TPS
rate(eth_transaction_count_total[5m])
```

***

## 五、配置 Grafana

### 5.1 访问 Grafana

浏览器打开：**<http://localhost:3000>**

默认登录信息：

- 用户名：`admin`
- 密码：`admin`

首次登录会提示修改密码，可以跳过或设置新密码。

### 5.2 添加 Prometheus 数据源

1. 点击左侧菜单 **Connections** → **Add new connection**
2. 搜索并选择 **Prometheus**
3. 配置数据源：
   - **Name**: `Prometheus`
   - **URL**: `http://prometheus:9090`（Docker 网络）或 `http://localhost:9090`（本地）
   - **Access**: `Server (default)`
4. 点击 **Save & Test**
5. 看到提示 **"Data source is working"** 表示成功

### 5.3 验证数据源

```bash
# 测试数据源连接
curl http://localhost:3000/api/datasources/proxy/1/api/v1/query?query=up

# 预期输出：
# {"status":"success","data":{"resultType":"vector","result":[...]}}
```

***

## 六、创建监控仪表盘

### 6.1 创建新仪表盘

1. 点击左侧菜单 **Dashboards** → **New Dashboard**
2. 点击 **Add visualization**
3. 选择 **Prometheus** 数据源

### 6.2 添加交易总数面板

**查询配置：**

```promql
eth_transaction_count_total
```

**面板设置：**

- **Title**: `交易总数`
- **Visualization**: `Stat`
- **Unit**: `none`

### 6.3 添加 Gas 消耗面板

**查询配置：**

```promql
eth_total_gas_used
```

**面板设置：**

- **Title**: `总 Gas 消耗`
- **Visualization**: `Stat`
- **Unit**: `none`

### 6.4 添加 TPS 面板

**查询配置：**

```promql
rate(eth_transaction_count_total[5m])
```

**面板设置：**

- **Title**: `TPS (每秒交易数)`
- **Visualization**: `Time series`
- **Unit**: `ops/sec`

### 6.5 添加成功率面板

**查询配置：**

```promql
# 成功交易占比
sum(rate(eth_transaction_count_total[5m])) 
  / 
sum(rate(eth_transaction_count_total[5m])) * 100
```

**面板设置：**

- **Title**: `交易成功率`
- **Visualization**: `Gauge`
- **Unit**: `percent (0-100)`
- **Thresholds**:
  - Red: `< 80`
  - Yellow: `80-95`
  - Green: `> 95`

### 6.6 保存仪表盘

1. 点击右上角 **Save dashboard**
2. 输入仪表盘名称：`区块链性能监控`
3. 点击 **Save**

***

## 七、监控指标体系

### 7.1 核心指标

| 指标名称                          | 类型    | 说明       | 告警阈值  |
| ----------------------------- | ----- | -------- | ----- |
| `eth_transaction_count_total` | Gauge | 交易总数     | -     |
| `eth_total_gas_used`          | Gauge | 总 Gas 消耗 | > 10M |
| `eth_scrape_timestamp`        | Gauge | 抓取时间戳    | -     |

### 7.2 计算指标

| 指标名称     | PromQL 查询                                          | 说明         |
| -------- | -------------------------------------------------- | ---------- |
| TPS      | `rate(eth_transaction_count_total[5m])`            | 每秒交易数      |
| 平均 Gas   | `eth_total_gas_used / eth_transaction_count_total` | 平均每笔交易 Gas |
| Gas 消耗速率 | `rate(eth_total_gas_used[5m])`                     | 每秒 Gas 消耗  |

### 7.3 推荐面板布局

```
┌─────────────────────────────────────────────────────────────┐
│                    区块链性能监控仪表盘                      │
├──────────────────┬──────────────────┬───────────────────────┤
│   交易总数       │   总 Gas 消耗    │   抓取时间戳          │
│   (Stat)         │   (Stat)         │   (Stat)              │
├──────────────────┴──────────────────┴───────────────────────┤
│                                                             │
│                    TPS 趋势图 (Time Series)                 │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                    Gas 消耗趋势图 (Time Series)              │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

***

## 八、告警配置

### 8.1 创建告警规则

在 Grafana 中配置告警：

1. 进入仪表盘编辑模式
2. 点击面板的 **Alert** 标签
3. 点击 **Create alert rule from this panel**

### 8.2 告警规则示例

**高 Gas 消耗告警：**

```yaml
# 条件
WHEN last() OF query(A) > 10000000

# 持续时间
FOR 5m

# 标签
severity: warning

# 注解
summary: "Gas 消耗过高"
description: "总 Gas 消耗超过 10M"
```

**低 TPS 告警：**

```yaml
# 条件
WHEN last() OF query(A) < 10

# 持续时间
FOR 10m

# 标签
severity: critical

# 注解
summary: "交易吞吐量低"
description: "TPS 低于 10 笔/秒"
```

### 8.3 配置通知渠道

1. 点击左侧菜单 **Alerting** → **Contact points**
2. 点击 **Add contact point**
3. 选择通知类型（Email、Slack、Webhook 等）
4. 配置通知参数
5. 点击 **Save contact point**

***

## 九、常用操作

### 9.1 服务管理

```bash
# 启动所有服务
cd /home/liuyoushan/ape-demo/perf/monitoring
docker compose up -d

# 停止所有服务
docker-compose down

# 重启服务
docker-compose restart

# 查看日志
docker-compose logs -f prometheus
docker-compose logs -f grafana
```

### 9.2 数据查询

```bash
# 查询交易总数
curl 'http://localhost:9090/api/v1/query?query=eth_transaction_count_total'

# 查询 Gas 消耗
curl 'http://localhost:9090/api/v1/query?query=eth_total_gas_used'

# 查询 TPS
curl 'http://localhost:9090/api/v1/query?query=rate(eth_transaction_count_total[5m])'

# 查询最近 1 小时的数据
curl 'http://localhost:9090/api/v1/query_range?query=eth_transaction_count_total&start='$(date -d '1 hour ago' +%s)'&end='$(date +%s)'&step=60'
```

### 9.3 仪表盘管理

```bash
# 导出仪表盘配置
curl http://localhost:3000/api/dashboards/uid/<uid> -H "Authorization: Bearer <api_key>" > dashboard.json

# 导入仪表盘配置
curl -X POST http://localhost:3000/api/dashboards/db -H "Content-Type: application/json" -d @dashboard.json
```

***

## 十、问题排查

### 10.1 常见问题

| 问题                       | 原因           | 解决方案                  |
| ------------------------ | ------------ | --------------------- |
| Prometheus 无法连接 Exporter | 网络配置错误       | 检查 targets 配置         |
| Grafana 无法连接 Prometheus  | 数据源配置错误      | 检查 URL 配置             |
| 指标数据为空                   | Exporter 未运行 | 启动 chain\_exporter.py |
| 容器启动失败                   | 端口被占用        | 检查端口占用情况              |

### 10.2 调试命令

```bash
# 检查容器状态
docker ps -a

# 查看容器日志
docker logs prometheus
docker logs grafana

# 检查网络连接
docker network ls
docker network inspect monitoring_default

# 进入容器调试
docker exec -it prometheus sh
docker exec -it grafana sh
```

### 10.3 重置环境

```bash
# 停止并删除所有容器
cd /home/liuyoushan/ape-demo/perf/monitoring
docker-compose down -v

# 重新启动
docker-compose up -d
```

***

## 附录：快速启动脚本

```bash
#!/bin/bash
# start_monitoring.sh

echo "=== 启动 Prometheus + Grafana 监控 ==="

# 1. 启动 Anvil 节点（如果未运行）
if ! pgrep anvil > /dev/null; then
    echo "启动 Anvil 节点..."
    anvil --host 127.0.0.1 --port 8545 --block-time 1 > /tmp/anvil.log 2>&1 &
    sleep 3
fi

# 2. 启动 Exporter
echo "启动 Chain Exporter..."
cd /home/liuyoushan/ape-demo/perf/monitoring
python3 chain_exporter.py > /tmp/exporter.log 2>&1 &
sleep 2

# 3. 启动 Prometheus 和 Grafana
echo "启动 Prometheus 和 Grafana..."
docker compose up -d

echo ""
echo "=== 监控服务已启动 ==="
echo "Prometheus: http://localhost:9090"
echo "Grafana:    http://localhost:3000 (admin/admin)"
echo "Exporter:   http://localhost:9100/metrics"
```

***

**文档结束**

***

> 📌 **提示**：此文档为 Prometheus + Grafana 全量监控专用教程。如需轻量级监控方案（无需 Docker），请参考 `SOP_LIGHT.md`。

