#!/usr/bin/env bash

set -euo pipefail

APP_NAME="Xray Manager"
PROJECT_DIR="$HOME/xray-manager"

show_menu() {
    clear

    echo "================================"
    echo "        $APP_NAME"
    echo "================================"
    echo
    echo "1. 检查系统环境"
    echo "2. 查看项目目录"
    echo "3. 查看 Python 版本"
    echo "4. 检查 Xray 安装状态"
    echo "5. 安装 Xray"
    echo "6. 查看 Xray 服务状态"
    echo "7. 启动 Xray 服务"
    echo "8. 停止 Xray 服务"
    echo "9. 重启 Xray 服务"
    echo "0. 退出"
    echo
}

check_system() {
    echo "========== 系统环境检查 =========="

    echo
    echo "【系统发行版】"
    grep '^PRETTY_NAME=' /etc/os-release

    echo
    echo "【系统架构】"
    uname -m

    echo
    echo "【当前用户】"
    whoami

    echo
    echo "【Root 权限检查】"
    if [ "$(id -u)" -eq 0 ]; then
        echo "当前具有 Root 权限"
    else
        echo "当前没有 Root 权限"
    fi

    echo
    echo "【curl 检查】"
    if command -v curl >/dev/null 2>&1; then
        echo "curl 已安装"
    else
        echo "curl 未安装"
    fi

    echo
    echo "【systemd 检查】"
    if command -v systemctl >/dev/null 2>&1; then
        echo "systemctl 已安装"
    else
        echo "systemctl 未安装"
    fi

    echo
    echo "========== 检查完成 =========="
}

show_project_dir() {
    echo "项目目录：$PROJECT_DIR"
    ls -lah "$PROJECT_DIR"
}

show_python_version() {
    python3 --version
}

check_xray() {
    echo "========== Xray 安装状态 =========="

    if command -v xray >/dev/null 2>&1; then
        echo "Xray 已安装"
        xray version
    else
        echo "Xray 尚未安装"
    fi

    echo "==================================="
}

install_xray() {
    echo "========== 安装 Xray =========="

    # 检查是否已经安装
    if command -v xray >/dev/null 2>&1; then
        echo "Xray 已经安装，无需重复安装"
        xray version
        return 0
    fi

    # 检查必要工具
    for cmd in curl jq unzip install; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "错误：缺少必要工具 $cmd"
            return 1
        fi
    done

    # 检查系统架构
    ARCH=$(uname -m)

    if [ "$ARCH" != "x86_64" ]; then
        echo "暂时只支持 x86_64 架构"
        return 1
    fi

    # 获取最新版本信息
    echo "正在获取 Xray 最新版本..."

    API_URL="https://api.github.com/repos/XTLS/Xray-core/releases/latest"

    RELEASE_INFO=$(curl -fsSL "$API_URL") || {
        echo "获取版本信息失败"
        return 1
    }

    # 获取下载地址
    DOWNLOAD_URL=$(echo "$RELEASE_INFO" | jq -r \
        '.assets[] | select(.name == "Xray-linux-64.zip") | .browser_download_url' \
        | head -n 1)

    if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" = "null" ]; then
        echo "未找到适用于 x86_64 的安装包"
        return 1
    fi

    echo "下载地址：$DOWNLOAD_URL"

    # 创建临时目录
    TMP_DIR=$(mktemp -d)

    # 下载文件
    echo "正在下载 Xray..."

    if ! curl -fL "$DOWNLOAD_URL" -o "$TMP_DIR/xray.zip"; then
        echo "下载失败"
        rm -rf "$TMP_DIR"
        return 1
    fi

    # 解压文件
    echo "正在解压..."

    if ! unzip -q "$TMP_DIR/xray.zip" -d "$TMP_DIR"; then
        echo "解压失败"
        rm -rf "$TMP_DIR"
        return 1
    fi

    # 检查二进制文件
    if [ ! -f "$TMP_DIR/xray" ]; then
        echo "安装包中没有找到 xray 文件"
        rm -rf "$TMP_DIR"
        return 1
    fi

    # 创建系统目录
    echo "正在创建安装目录..."

    sudo mkdir -p /usr/local/bin
    sudo mkdir -p /usr/local/etc/xray
    sudo mkdir -p /usr/local/share/xray

    # 安装二进制文件
    echo "正在安装 Xray..."

    if ! sudo install -m 755 "$TMP_DIR/xray" /usr/local/bin/xray; then
        echo "安装失败"
        rm -rf "$TMP_DIR"
        return 1
    fi

    # 安装 GeoIP 和 GeoSite 资源文件（如果存在）
    for file in geoip.dat geosite.dat; do
        if [ -f "$TMP_DIR/$file" ]; then
            sudo install -m 644 "$TMP_DIR/$file" \
                "/usr/local/share/xray/$file"
        fi
    done

    # 清理临时文件
    rm -rf "$TMP_DIR"

    # 检查安装结果
    echo
    echo "========== 安装结果 =========="

    if /usr/local/bin/xray version; then
        echo "Xray 安装成功！"
    else
        echo "Xray 安装失败，请检查系统环境"
        return 1
    fi
}

# 查看 Xray 服务状态
xray_status() {
    echo "========== Xray 服务状态 =========="

    if ! command -v systemctl >/dev/null 2>&1; then
        echo "错误：当前系统不支持 systemctl"
        return 1
    fi

    if systemctl is-active --quiet xray; then
        echo "Xray 当前正在运行"
    else
        echo "Xray 当前未运行"
    fi

    echo
    sudo systemctl status xray --no-pager
}
# 启动 Xray 服务
xray_start() {
    echo "========== 启动 Xray 服务 =========="

    if ! command -v systemctl >/dev/null 2>&1; then
        echo "错误：当前系统不支持 systemctl"
        return 1
    fi

    if systemctl is-active --quiet xray; then
        echo "Xray 已经在运行，无需重复启动"
        return 0
    fi

    if sudo systemctl start xray; then
        echo "Xray 启动成功"
    else
        echo "Xray 启动失败，请检查服务日志"
        return 1
    fi
}
# 停止 Xray 服务
xray_stop() {
    echo "========== 停止 Xray 服务 =========="

    if ! command -v systemctl >/dev/null 2>&1; then
        echo "错误：当前系统不支持 systemctl"
        return 1
    fi

    if ! systemctl is-active --quiet xray; then
        echo "Xray 已经停止，无需重复操作"
        return 0
    fi

    if sudo systemctl stop xray; then
        echo "Xray 已停止"
    else
        echo "Xray 停止失败，请检查服务日志"
        return 1
    fi
}
# 重启 Xray 服务
xray_restart() {
    echo "========== 重启 Xray 服务 =========="

    if ! command -v systemctl >/dev/null 2>&1; then
        echo "错误：当前系统不支持 systemctl"
        return 1
    fi

    if sudo systemctl restart xray; then
        echo "Xray 重启成功"
    else
        echo "Xray 重启失败，请检查服务日志"
        return 1
    fi
}

main() {
    while true; do
        show_menu

        read -r -p "请输入选项：" choice

        case "$choice" in
            1)
                check_system
                ;;
            2)
                show_project_dir
                ;;
            3)
                show_python_version
                ;;
            4)
                check_xray
                ;;
            5)
                install_xray
                ;;
            6)
                xray_status
                ;;
            7)
                xray_start
                ;;
            8)
                xray_stop
                ;;
            9)
                xray_restart
                ;;
            0)
                echo "退出程序"
                break
                ;;
            *)
                echo "无效选项，请重新输入"
                ;;
        esac

        echo
        read -r -p "按回车键继续..."
    done
}

main