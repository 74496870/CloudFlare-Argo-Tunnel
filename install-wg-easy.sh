#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# WG-Easy 一键安装脚本
# 用法:
#   交互模式: bash install-wg-easy.sh
#   静默模式: bash install-wg-easy.sh --host wg.example.com --password mypass
# ============================================================

DATA_DIR="/root/.wg-easy"
ENV_FILE="${DATA_DIR}/.wg-easy.env"
CONTAINER_NAME="wg-easy"
IMAGE="ghcr.io/wg-easy/wg-easy:latest"
WG_PORT="${WG_PORT:-51820}"
UI_PORT="${UI_PORT:-51821}"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; exit 1; }

# ---- 解析参数 ----
WG_HOST=""
PASSWORD=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)     WG_HOST="$2"; shift 2 ;;
    --password) PASSWORD="$2"; shift 2 ;;
    --wg-port)  WG_PORT="$2"; shift 2 ;;
    --ui-port)  UI_PORT="$2"; shift 2 ;;
    -h|--help)
      echo "用法: $0 [--host <域名/IP>] [--password <密码>] [--wg-port <端口>] [--ui-port <端口>]"
      exit 0 ;;
    *) error "未知参数: $1" ;;
  esac
done

# ---- 检查 Docker ----
if ! command -v docker &>/dev/null; then
  warn "Docker 未安装，正在安装..."
  if command -v apt-get &>/dev/null; then
    apt-get update -qq && apt-get install -y -qq docker.io
  elif command -v yum &>/dev/null; then
    yum install -y docker
    systemctl enable --now docker
  elif command -v dnf &>/dev/null; then
    dnf install -y docker
    systemctl enable --now docker
  else
    error "无法自动安装 Docker，请手动安装后重试"
  fi
  info "Docker 安装完成"
fi

# 确保 Docker 运行
if ! docker info &>/dev/null; then
  systemctl start docker 2>/dev/null || service docker start 2>/dev/null || true
  sleep 2
  docker info &>/dev/null || error "Docker 无法启动"
fi
info "Docker 就绪"

# ---- 交互式获取参数 ----
if [[ -z "$WG_HOST" ]]; then
  read -rp "请输入 WireGuard 服务域名或公网 IP: " WG_HOST
  [[ -z "$WG_HOST" ]] && error "域名/IP 不能为空"
fi

if [[ -z "$PASSWORD" ]]; then
  read -rsp "请输入 Web UI 登录密码: " PASSWORD
  echo
  [[ -z "$PASSWORD" ]] && error "密码不能为空"
fi

# ---- 生成密码 Hash ----
info "生成密码 Hash..."
PASSWORD_HASH=$(docker run --rm "$IMAGE" wgpw "$PASSWORD" 2>/dev/null | tail -1)
if [[ -z "$PASSWORD_HASH" ]]; then
  error "密码 Hash 生成失败（镜像拉取可能超时）"
fi
info "密码 Hash 生成成功"

# ---- 创建数据目录和环境变量文件 ----
mkdir -p "$DATA_DIR"

cat > "$ENV_FILE" <<EOF
PASSWORD_HASH=${PASSWORD_HASH}
WG_HOST=${WG_HOST}
WG_DEFAULT_ADDRESS=10.10.10.x
WG_DEFAULT_DNS=223.5.5.5, 223.6.6.6
WG_ALLOWED_IPS=10.10.10.0/24
WG_PERSISTENT_KEEPALIVE=25
EOF

chmod 600 "$ENV_FILE"
info "环境变量写入 ${ENV_FILE}"

# ---- 停止旧容器（如果存在）----
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  warn "检测到已有容器 ${CONTAINER_NAME}，正在停止并删除..."
  docker stop "$CONTAINER_NAME" 2>/dev/null || true
  docker rm "$CONTAINER_NAME" 2>/dev/null || true
fi

# ---- 启动容器 ----
info "启动 WG-Easy 容器..."
docker run -d \
  --name "$CONTAINER_NAME" \
  --restart unless-stopped \
  --env-file "$ENV_FILE" \
  -v "${DATA_DIR}:/etc/wireguard" \
  -p "${WG_PORT}:51820/udp" \
  -p "${UI_PORT}:51821/tcp" \
  --cap-add NET_ADMIN \
  --cap-add SYS_MODULE \
  --sysctl net.ipv4.conf.all.src_valid_mark=1 \
  --sysctl net.ipv4.ip_forward=1 \
  "$IMAGE"

# ---- 等待启动 ----
sleep 3
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  info "WG-Easy 启动成功！"
else
  error "容器启动失败，请检查: docker logs ${CONTAINER_NAME}"
fi

# ---- 输出信息 ----
echo ""
echo "============================================"
echo -e " ${GREEN}WG-Easy 安装完成${NC}"
echo "============================================"
echo " Web UI:     http://${WG_HOST}:${UI_PORT}"
echo " WireGuard:  ${WG_HOST}:${WG_PORT}/udp"
echo " 数据目录:   ${DATA_DIR}"
echo " 容器名称:   ${CONTAINER_NAME}"
echo "============================================"
echo ""
echo "常用命令:"
echo "  查看日志:  docker logs ${CONTAINER_NAME} --tail 50"
echo "  重启:      docker restart ${CONTAINER_NAME}"
echo "  停止:      docker stop ${CONTAINER_NAME}"
echo "  卸载:      docker stop ${CONTAINER_NAME} && docker rm ${CONTAINER_NAME}"
echo ""
