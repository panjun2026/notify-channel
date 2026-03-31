#!/bin/bash
#
# notify-channel - Shell 通知渠道抽象层
# 支持多渠道统一发送告警/通知
#

set -euo pipefail

# ========== 配置 ==========
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.env"

# 加载配置
if [[ -f "${CONFIG_FILE}" ]]; then
    source "${CONFIG_FILE}"
fi

# 颜色输出
RED=$(tput setaf 1 2>/dev/null || echo "")
GREEN=$(tput setaf 2 2>/dev/null || echo "")
YELLOW=$(tput setaf 3 2>/dev/null || echo "")
BLUE=$(tput setaf 4 2>/dev/null || echo "")
NC=$(tput sgr0 2>/dev/null || echo "")

# ========== 飞书渠道 ==========
send_feishu() {
    local message="$1"
    local card_color="${2:-gray}"  # gray, red, orange, yellow, green, blue, purple
    
    # 颜色映射
    local template="gray"
    case "$card_color" in
        red)    template="red" ;;
        orange) template="orange" ;;
        yellow) template="yellow" ;;
        green)  template="green" ;;
        blue)   template="blue" ;;
        purple) template="purple" ;;
    esac
    
    # emoji 前缀
    local emoji="📢"
    case "$card_color" in
        red)    emoji="🚨" ;;
        orange) emoji="⚠️" ;;
        green)  emoji="✅" ;;
        blue)   emoji="💬" ;;
        purple) emoji="🎯" ;;
    esac
    
    local hostname=$(hostname 2>/dev/null || echo "unknown")
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    local payload=$(cat << EOF
{
    "msg_type": "interactive",
    "card": {
        "header": {
            "title": {"tag": "plain_text", "content": "${emoji} 通知"},
            "template": "${template}"
        },
        "elements": [
            {"tag": "div", "text": {"tag": "lark_md", "content": "**主机:** ${hostname}\n**时间:** ${timestamp}\n\n${message}"}}
        ]
    }
}
EOF
)
    
    if [[ -z "${FEISHU_WEBHOOK:-}" ]] || [[ "$FEISHU_WEBHOOK" == *"YOUR_HOOK"* ]]; then
        echo -e "${RED}[ERROR]${NC} 飞书 Webhook 未配置"
        return 1
    fi
    
    local response=$(curl -s -X POST "${FEISHU_WEBHOOK}" \
        -H "Content-Type: application/json" \
        -d "${payload}")
    
    if echo "$response" | grep -q '"code":0'; then
        [[ "${INTERACTIVE:-0}" == "1" ]] && echo -e "${GREEN}[OK]${NC} 飞书发送成功"
        return 0
    else
        echo -e "${RED}[ERROR]${NC} 飞书发送失败: $response"
        return 1
    fi
}

# ========== 企业微信渠道 ==========
send_wecom() {
    local message="$1"
    
    if [[ -z "${WECOM_WEBHOOK:-}" ]]; then
        echo -e "${RED}[ERROR]${NC} 企业微信 Webhook 未配置"
        return 1
    fi
    
    local payload=$(cat << EOF
{
    "msgtype": "text",
    "text": {
        "content": "$(hostname): ${message}"
    }
}
EOF
)
    
    local response=$(curl -s -X POST "${WECOM_WEBHOOK}" \
        -H "Content-Type: application/json" \
        -d "${payload}")
    
    if echo "$response" | grep -q '"errcode":0'; then
        [[ "${INTERACTIVE:-0}" == "1" ]] && echo -e "${GREEN}[OK]${NC} 企业微信发送成功"
        return 0
    else
        echo -e "${RED}[ERROR]${NC} 企业微信发送失败: $response"
        return 1
    fi
}

# ========== Telegram 渠道 ==========
send_telegram() {
    local message="$1"
    
    if [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]] || [[ -z "${TELEGRAM_CHAT_ID:-}" ]]; then
        echo -e "${RED}[ERROR]${NC} Telegram 配置不完整"
        return 1
    fi
    
    local encoded_message=$(echo "$message" | sed 's/ /%20/g' | sed 's/\n/%0A/g')
    local url="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage?chat_id=${TELEGRAM_CHAT_ID}&text=${encoded_message}"
    
    local response=$(curl -s -X GET "$url")
    
    if echo "$response" | grep -q '"ok":true'; then
        [[ "${INTERACTIVE:-0}" == "1" ]] && echo -e "${GREEN}[OK]${NC} Telegram 发送成功"
        return 0
    else
        echo -e "${RED}[ERROR]${NC} Telegram 发送失败: $response"
        return 1
    fi
}

# ========== 通用发送函数 ==========
send() {
    local message="$1"
    shift
    local channels=("$@")
    
    local success_count=0
    local fail_count=0
    
    for channel in "${channels[@]}"; do
        case "$channel" in
            feishu|lark)
                send_feishu "$message" && ((success_count++)) || ((fail_count++))
                ;;
            wecom|wx)
                send_wecom "$message" && ((success_count++)) || ((fail_count++))
                ;;
            telegram|tg)
                send_telegram "$message" && ((success_count++)) || ((fail_count++))
                ;;
            all)
                # 发送到所有已配置的渠道
                [[ -n "${FEISHU_WEBHOOK:-}" ]] && [[ "$FEISHU_WEBHOOK" != *"YOUR_HOOK"* ]] && \
                    send_feishu "$message" && ((success_count++)) || ((fail_count++))
                [[ -n "${WECOM_WEBHOOK:-}" ]] && \
                    send_wecom "$message" && ((success_count++)) || ((fail_count++))
                [[ -n "${TELEGRAM_BOT_TOKEN:-}" ]] && [[ -n "${TELEGRAM_CHAT_ID:-}" ]] && \
                    send_telegram "$message" && ((success_count++)) || ((fail_count++))
                ;;
            *)
                echo -e "${RED}[ERROR]${NC} 未知渠道: $channel"
                ((fail_count++))
                ;;
        esac
    done
    
    if [[ "$success_count" -gt 0 ]] && [[ "$fail_count" -eq 0 ]]; then
        return 0
    elif [[ "$success_count" -eq 0 ]] && [[ "$fail_count" -gt 0 ]]; then
        return 1
    else
        return 2  # 部分成功
    fi
}

# ========== 帮助 ==========
show_help() {
    cat << EOF
notify-channel - Shell 通知渠道抽象层

用法: $0 <command> [选项]

命令:
    send <消息> <渠道...>    发送通知到指定渠道
    list                      列出支持的渠道
    test <渠道>               测试指定渠道
    help                      显示帮助

渠道:
    feishu, lark              飞书机器人
    wecom, wx                 企业微信机器人
    telegram, tg              Telegram Bot
    all                       所有已配置的渠道

示例:
    $0 send "Hello World" feishu
    $0 send "Alert!" all
    $0 test feishu
    $0 list

配置:
    编辑 config.env 文件配置各渠道 Webhook

EOF
}

# ========== 主入口 ==========
main() {
    INTERACTIVE=0
    local card_color="gray"
    
    # 解析参数
    local cmd="${1:-help}"
    shift || true
    
    case "$cmd" in
        send)
            local message=""
            local channels=()
            
            # 解析剩余参数
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --interactive|-i)
                        INTERACTIVE=1
                        ;;
                    --card)
                        card_color="$2"
                        shift
                        ;;
                    --interactive=*)
                        INTERACTIVE=1
                        ;;
                    --card=*)
                        card_color="${1#*=}"
                        ;;
                    -*)
                        echo "未知选项: $1"
                        exit 1
                        ;;
                    *)
                        if [[ -z "$message" ]]; then
                            message="$1"
                        else
                            channels+=("$1")
                        fi
                        ;;
                esac
                shift
            done
            
            if [[ -z "$message" ]]; then
                echo "错误: 未指定消息内容"
                exit 1
            fi
            
            if [[ ${#channels[@]} -eq 0 ]]; then
                echo "错误: 未指定渠道"
                exit 1
            fi
            
            send "$message" "${channels[@]}"
            ;;
        list)
            echo "支持的渠道:"
            echo "  feishu    - 飞书机器人"
            echo "  wecom     - 企业微信机器人"
            echo "  telegram  - Telegram Bot"
            echo "  all       - 所有已配置渠道"
            ;;
        test)
            local channel="${1:-feishu}"
            INTERACTIVE=1
            send "[测试] notify-channel 通道测试 $(date '+%H:%M:%S')" "$channel"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo "未知命令: $cmd"
            echo "使用 '$0 help' 查看帮助"
            exit 1
            ;;
    esac
}

main "$@"
