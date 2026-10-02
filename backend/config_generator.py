import json
from backend.nodes import get_nodes

def generate_node_config(node):
    """根据节点信息生成完整的 Xray 客户端配置"""

    # 获取传输方式和安全方式
    network = node.get("network") or "tcp"
    security = node.get("security") or "none"

    # 构建传输层配置
    stream_settings = {
        "network": network,
        "security": security
    }

    # 如果启用 TLS，添加 TLS 配置
    if security == "tls":
        stream_settings["tlsSettings"] = {
            "serverName": node.get("server_name") or node["address"]
        }

    # 如果启用 TLS，添加 TLS 配置
    if security == "tls":
        stream_settings["tlsSettings"] = {
            "serverName": node.get("server_name") or node["address"]
        }

    # 如果使用 WebSocket，添加 WebSocket 配置
    if network == "ws":
        stream_settings["wsSettings"] = {
            "path": node.get("path") or "/"
        }


    config = {
        "log": {
            "loglevel": "warning"
        },

        # 本地 SOCKS5 代理入口
        "inbounds": [
            {
                "tag": "socks-in",
                "listen": "127.0.0.1",
                "port": 10808,
                "protocol": "socks",
                "settings": {
                    "auth": "noauth",
                    "udp": True
                }
            }
        ],

        # 远程代理服务器出口
        "outbounds": [
            {
                "tag": "proxy",
                "protocol": "vless",
                "settings": {
                    "vnext": [
                        {
                            "address": node["address"],
                            "port": node["port"],
                            "users": [
                                {
                                    "id": node["uuid"],
                                    "encryption": "none"
                                }
                            ]
                        }
                    ]
                },
                "streamSettings": stream_settings
            },
            {
                "tag": "direct",
                "protocol": "freedom"
            }
        ]
    }

    return config

def generate_config_for_node(node_id):
    """根据节点 ID 生成 Xray 配置"""

    nodes = get_nodes()

    # 查找指定的节点
    node = next(
        (item for item in nodes if item["id"] == node_id),
        None
    )

    if node is None:
        raise ValueError(f"找不到 ID 为 {node_id} 的节点")

    # 生成节点配置
    config = generate_node_config(node)

    return config

from pathlib import Path


def save_config_to_file(config, filename="generated.json"):
    """将 Xray 配置保存为 JSON 文件"""

    # 获取项目根目录
    base_dir = Path(__file__).resolve().parent.parent

    # 配置文件保存目录
    config_dir = base_dir / "config"

    # 确保目录存在
    config_dir.mkdir(parents=True, exist_ok=True)

    # 拼接完整文件路径
    file_path = config_dir / filename

    # 写入 JSON 文件
    with open(file_path, "w", encoding="utf-8") as file:
        json.dump(config, file, indent=2, ensure_ascii=False)

    return file_path

if __name__ == "__main__":
    print("Xray 配置生成器已创建")