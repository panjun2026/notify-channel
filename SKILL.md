# notify-channel

Shell 通知渠道抽象层，支持多渠道（飞书、微信、Telegram 等）统一发送告警/通知。

## 功能

- 统一的通知接口，切换渠道只需改配置
- 支持多个渠道同时发送
- 轻量无依赖，仅需 curl

## 目录结构

```
notify-channel/
├── notify.sh          # 主脚本，通用接口
├── config.env         # 渠道配置
├── channels/
│   └── feishu.sh     # 飞书实现
└── README.md
```

## 快速开始

### 1. 配置

编辑 `config.env`，填入各渠道的 Webhook 地址：

```bash
# 飞书
FEISHU_WEBHOOK="https://open.feishu.cn/open-apis/bot/v2/hook/YOUR_HOOK"

# 企业微信（可选）
WECOM_WEBHOOK="https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=YOUR_KEY"

# Telegram Bot（可选）
TELEGRAM_BOT_TOKEN="123456:ABC-DEF..."
TELEGRAM_CHAT_ID="CHAT_ID"
```

### 2. 使用

```bash
# 发送到飞书
./notify.sh send "告警内容" feishu

# 发送到所有已配置渠道
./notify.sh send "告警内容" all

# 使用交互模式（带颜色）
./notify.sh send "告警内容" feishu --interactive
```

## 高级用法

### 在其他脚本中调用

```bash
# 方式1：直接路径调用
/root/skills/notify-channel/notify.sh send "Hello" feishu

# 方式2：复制到系统路径
cp notify.sh /usr/local/bin/notify
notify send "Hello" feishu
```

### 调用示例

```bash
#!/bin/bash
# 在你的监控脚本中调用

RESULT=$(your-monitor-command)
if [[ $? -ne 0 ]]; then
    /path/to/notify.sh send "监控失败: $RESULT" all
fi
```

## 支持的渠道

| 渠道 | 状态 | 说明 |
|------|------|------|
| feishu | ✅ 已实现 | 飞书机器人 Webhook |
| wecom | 📋 待实现 | 企业微信机器人 |
| telegram | 📋 待实现 | Telegram Bot |
| dingtalk | 📋 待实现 | 钉钉机器人 |
| pushplus | 📋 待实现 | 推送加 |

## 消息格式

### 飞书

支持 text 和 interactive card 两种格式：

```bash
# text 格式
./notify.sh send "简单文本" feishu

# card 格式（可自定义颜色）
./notify.sh send "严重告警" feishu --card red
```

## 许可证

MIT
