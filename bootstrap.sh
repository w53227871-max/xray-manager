#!/bin/bash

set -e

REPO="https://github.com/w53227871-max/xray-manager.git"
PROJECT_DIR="$HOME/xray-manager"

echo "======================================"
echo "       Xray Manager 一键安装"
echo "======================================"
echo

if [ "$(id -u)" -eq 0 ]; then
    echo "错误：请不要使用 root 运行。"
    echo "请使用普通用户运行此命令。"
    exit 1
fi

if ! command -v git >/dev/null 2>&1; then
    echo "错误：未找到 git。"
    echo
    echo "请先安装："
    echo "  sudo apt update"
    echo "  sudo apt install -y git"
    exit 1
fi

if [ -d "$PROJECT_DIR/.git" ]; then
    echo "检测到已有 Xray Manager 项目。"
    echo "正在更新项目..."

    cd "$PROJECT_DIR"
    git pull --ff-only
else
    echo "正在从 GitHub 获取 Xray Manager..."

    if [ -e "$PROJECT_DIR" ]; then
        echo "错误：$PROJECT_DIR 已存在，但不是 Git 仓库。"
        exit 1
    fi

    git clone "$REPO" "$PROJECT_DIR"
    cd "$PROJECT_DIR"
fi

echo
echo "项目准备完成：$PROJECT_DIR"
echo

chmod +x "$PROJECT_DIR/install.sh"

echo "开始执行安装程序..."
echo

exec "$PROJECT_DIR/install.sh"