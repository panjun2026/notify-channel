# notify-channel

Shell 通知渠道抽象层，一套脚本支持多渠道发送告警/通知。

## 特性

- 🚀 **零依赖** - 只需 curl
- 🔌 **即插即用** - 配置简单
- 📦 **可扩展** - 轻松添加新渠道
- 🎨 **彩色卡片** - 支持不同颜色级别

## 支持的渠道

| 渠道 | 状态 | 说明 |
|------|------|------|
| 飞书 | ✅ 已实现 | 支持 text 和 interactive card |
| 企业微信 | ✅ 已实现 | text 消息 |
| Telegram | ✅ 已实现 | Bot API |

## 快速开始

### 1. 下载

```bash
git clone https://github.com/yourname/notify-channel.git
cd notify-channel
```

### 2. 配置

```bash
cp config.env.example config.env
# 编辑 config.env，填入你的 Webhook 地址
```

### 3. 使用

```bash
# 发送简单消息
./notify.sh send "服务故障" feishu

# 发送到所有渠道
./notify.sh send "系统告警" all

# 使用交互模式
./notify.sh send "严重问题" feishu --interactive

# 使用彩色卡片
./notify.sh send "红色警报" feishu --card red
```

## 在其他脚本中使用

```bash
#!/bin/bash
# 检测到故障后发送通知
if ! curl -s http://localhost:8080/health > /dev/null; then
    /path/to/notify.sh send "服务不可用" feishu
fi
```

## 与其他项目集成

### OpenClaw 巡检脚本

```bash
# 原来
curl -X POST "https://open.feishu.cn/..." -d '{"msg_type":"text",...}'

# 改成
source /path/to/notify-channel/notify.sh
send "告警内容" feishu
```

## 开发

### 添加新渠道

1. 在 `notify.sh` 中添加 `send_<channel>()` 函数
2. 在 `send()` 函数的 case 语句中添加渠道处理
3. 在 `config.env` 中添加配置项

## License

MIT
