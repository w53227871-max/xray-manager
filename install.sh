#!/bin/bash

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="$PROJECT_DIR/.venv"

echo "======================================"
echo "       Xray Manager 安装程序"
echo "======================================"
echo

echo "[1/6] 检查运行环境..."

if [ "$(id -u)" -eq 0 ]; then
    echo "错误：请不要使用 root 运行此安装程序。"
    echo "请使用普通用户运行，例如："
    echo "  ./install.sh"
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "错误：未找到 python3"
    exit 1
fi

echo "Python: $(python3 --version)"
echo "项目目录: $PROJECT_DIR"
echo "安装用户: $(whoami)"
echo
echo "[2/6] 检查系统环境..."

if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "系统: $PRETTY_NAME"
else
    echo "警告：无法检测系统版本"
fi

PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')

echo "Python 主版本: $PYTHON_VERSION"

if [ "$(printf '%s\n' "3.10" "$PYTHON_VERSION" | sort -V | head -n1)" != "3.10" ]; then
    echo "错误：Python 版本过低，需要 Python 3.10 或更高版本。"
    exit 1
fi

echo "Python 版本检查通过。"

echo
echo "检查 Python 虚拟环境..."

if [ ! -d "$VENV_DIR" ]; then
    echo "未找到虚拟环境，正在创建..."
    python3 -m venv "$VENV_DIR"
else
    echo "虚拟环境已存在：$VENV_DIR"
fi

echo "虚拟环境准备完成。"
echo
echo "[3/6] 安装 Python 依赖..."

if [ ! -f "$PROJECT_DIR/requirements.txt" ]; then
    echo "错误：未找到 requirements.txt"
    exit 1
fi

"$VENV_DIR/bin/python" -m pip install --upgrade pip
"$VENV_DIR/bin/pip" install -r "$PROJECT_DIR/requirements.txt"

echo "Python 依赖安装完成。"
echo
echo "[4/6] 检查 Xray..."

XRAY_BIN="/usr/local/bin/xray"

if [ -x "$XRAY_BIN" ]; then
    echo "检测到 Xray：$XRAY_BIN"
    echo
    "$XRAY_BIN" version | head -n 2
    echo
    echo "Xray 已安装，跳过安装。"
else
    echo "未检测到 Xray，开始安装..."

    if ! command -v curl >/dev/null 2>&1; then
        echo "错误：未找到 curl"
        echo "请先安装 curl：sudo apt install curl"
        exit 1
    fi

    if ! command -v unzip >/dev/null 2>&1; then
        echo "错误：未找到 unzip"
        echo "请先安装 unzip：sudo apt install unzip"
        exit 1
    fi

    ARCH="$(uname -m)"

    case "$ARCH" in
        x86_64)
            XRAY_ARCH="64"
            ;;
        aarch64|arm64)
            XRAY_ARCH="arm64-v8a"
            ;;
        *)
            echo "错误：暂不支持的 CPU 架构：$ARCH"
            exit 1
            ;;
    esac

    echo "CPU 架构：$ARCH"
    echo "Xray 架构：$XRAY_ARCH"

    echo "获取最新 Xray 版本..."

    XRAY_VERSION="$(
        curl -fsSL https://api.github.com/repos/XTLS/Xray-core/releases/latest \
        | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])'
    )"

    if [ -z "$XRAY_VERSION" ]; then
        echo "错误：无法获取 Xray 最新版本。"
        exit 1
    fi

    echo "最新版本：$XRAY_VERSION"

    XRAY_URL="https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-linux-${XRAY_ARCH}.zip"

    TMP_DIR="$(mktemp -d)"

    echo "下载 Xray..."
    curl -fL "$XRAY_URL" -o "$TMP_DIR/xray.zip"

    echo "解压 Xray..."
    unzip -q "$TMP_DIR/xray.zip" -d "$TMP_DIR/xray"

    if [ ! -f "$TMP_DIR/xray/xray" ]; then
        echo "错误：Xray 文件未找到。"
        rm -rf "$TMP_DIR"
        exit 1
    fi

    echo "安装 Xray 到 $XRAY_BIN..."
    sudo install -m 755 "$TMP_DIR/xray/xray" "$XRAY_BIN"

    rm -rf "$TMP_DIR"

    echo
    echo "Xray 安装完成："
    "$XRAY_BIN" version | head -n 2
fi

echo
echo "[5/6] 检查 Xray systemd 服务..."

XRAY_SERVICE="/etc/systemd/system/xray.service"

if [ -f "$XRAY_SERVICE" ]; then
    echo "检测到 Xray systemd 服务：$XRAY_SERVICE"
else
    echo "未检测到 Xray systemd 服务，正在创建..."

    sudo tee "$XRAY_SERVICE" > /dev/null <<EOF
[Unit]
Description=Xray Service
Documentation=https://github.com/XTLS/Xray-core
After=network.target nss-lookup.target

[Service]
User=xray
Group=xray
Type=simple
ExecStart=/usr/local/bin/xray run -config /usr/local/etc/xray/config.json
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    echo "Xray systemd 服务文件创建完成。"
fi

if ! id xray >/dev/null 2>&1; then
    echo "创建 xray 系统用户..."
    sudo useradd --system --no-create-home --shell /usr/sbin/nologin xray
fi

sudo mkdir -p /usr/local/etc/xray

if [ ! -f /usr/local/etc/xray/config.json ]; then
    echo "未找到 Xray 配置文件，创建基础配置..."

    sudo tee /usr/local/etc/xray/config.json > /dev/null <<'EOF'
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    }
  ]
}
EOF
fi

sudo chown -R xray:xray /usr/local/etc/xray
sudo chmod 755 /usr/local/etc/xray
sudo chmod 644 /usr/local/etc/xray/config.json

sudo systemctl daemon-reload
sudo systemctl enable xray
sudo systemctl restart xray

echo
echo "检查 Xray 服务状态..."

if sudo systemctl is-active --quiet xray; then
    echo "Xray 服务运行正常。"
else
    echo "错误：Xray 服务启动失败。"
    sudo systemctl status xray --no-pager -l
    echo
    echo "最近日志："
    sudo journalctl -u xray -n 20 --no-pager
    exit 1
fi

echo
echo "检查 Xray 配置..."

XRAY_TEST_LOG="$(mktemp)"

if sudo /usr/local/bin/xray -test -config /usr/local/etc/xray/config.json > "$XRAY_TEST_LOG" 2>&1; then
    echo "Xray 配置检查通过。"
    rm -f "$XRAY_TEST_LOG"
else
    echo "错误：Xray 配置检查失败。"
    cat "$XRAY_TEST_LOG"
    rm -f "$XRAY_TEST_LOG"
    exit 1
fi

echo
echo "Xray systemd 服务准备完成。"

echo
echo "[6/6] 配置 Xray Manager systemd 服务..."

MANAGER_SERVICE="/etc/systemd/system/xray-manager.service"

if [ ! -f "$MANAGER_SERVICE" ]; then
    echo "未检测到 Xray Manager systemd 服务，正在创建..."

    sudo tee "$MANAGER_SERVICE" > /dev/null <<EOF
[Unit]
Description=Xray Manager Web Panel
After=network.target xray.service

[Service]
Type=simple
User=$(whoami)
Group=$(id -gn)
WorkingDirectory=$PROJECT_DIR
ExecStart=$VENV_DIR/bin/python -m uvicorn backend.main:app --host 127.0.0.1 --port 8000
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    echo "Xray Manager systemd 服务创建完成。"
else
    echo "检测到已有 Xray Manager systemd 服务，跳过创建。"
fi

sudo systemctl daemon-reload
sudo systemctl enable xray-manager
sudo systemctl restart xray-manager

echo
echo "检查 Xray Manager 服务状态..."

if sudo systemctl is-active --quiet xray-manager; then
    echo "Xray Manager 服务运行正常。"
else
    echo "错误：Xray Manager 服务启动失败。"
    sudo systemctl status xray-manager --no-pager -l
    exit 1
fi

echo
echo "等待 Web API 启动..."

API_READY=false

for i in {1..10}; do
    if curl -fsS http://127.0.0.1:8000/health > /dev/null 2>&1; then
        API_READY=true
        break
    fi

    echo "等待中... ($i/10)"
    sleep 1
done

if [ "$API_READY" = true ]; then
    echo "Web API 检查通过。"
else
    echo "错误：Web API 启动失败。"
    sudo systemctl status xray-manager --no-pager -l
    echo
    echo "最近日志："
    sudo journalctl -u xray-manager -n 20 --no-pager
    exit 1
fi

echo
echo "======================================"
echo "       Xray Manager 安装完成"
echo "======================================"
echo
echo "面板地址：http://127.0.0.1:8000/panel"
echo
echo "服务状态："
echo "  Xray         : $(sudo systemctl is-active xray)"
echo "  Xray Manager : $(sudo systemctl is-active xray-manager)"
echo