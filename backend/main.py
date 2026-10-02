from pydantic import BaseModel, Field
from fastapi import FastAPI, HTTPException
import subprocess
import socket
import time
from pathlib import Path
from fastapi.responses import FileResponse
from backend.nodes import get_nodes, create_node, update_node, delete_node
from backend.settings import get_setting, set_setting

# 创建 FastAPI 应用
app = FastAPI(
    title="Xray Manager",
    description="Xray 服务管理后端",
    version="0.1.0"
)

@app.get("/panel")
def panel():
    """返回网页管理面板"""

    html_path = Path(__file__).resolve().parent.parent / "frontend" / "index.html"

    return FileResponse(html_path)

class NodeCreate(BaseModel):
    name: str
    protocol: str
    address: str
    port: int = Field(ge=1, le=65535)
    network: str = "tcp"
    security: str = "none"
    server_name: str = ""
    path: str = ""

class NodeUpdate(BaseModel):
    name: str
    protocol: str
    address: str
    port: int = Field(ge=1, le=65535)
    network: str = "tcp"
    security: str = "none"
    server_name: str = ""
    path: str = ""


# 首页接口
@app.get("/")
def index():
    return {
        "message": "Welcome to Xray Manager",
        "version": "0.1.0"
    }


# 健康检查接口
@app.get("/health")
def health_check():
    return {
        "status": "ok"
    }

@app.get("/api/nodes")
def read_nodes():
    """获取所有节点"""
    return get_nodes()

@app.post("/api/nodes")
def add_node(node: NodeCreate):
    """添加一个节点"""

    node_id = create_node(
        node.name,
        node.protocol,
        node.address,
        node.port,
        node.network,
        node.security,
        node.server_name,
        node.path
    )

    return {
        "message": "节点添加成功",
        "id": node_id
    }

@app.put("/api/nodes/{node_id}")
def edit_node(node_id: int, node: NodeUpdate):
    """修改节点信息"""

    updated = update_node(
        node_id,
        node.name,
        node.protocol,
        node.address,
        node.port,
        node.network,
        node.security,
        node.server_name,
        node.path
    )

    if not updated:
        raise HTTPException(
            status_code=404,
            detail="节点不存在"
        )

    return {
        "message": "节点修改成功",
        "id": node_id
    }

@app.delete("/api/nodes/{node_id}")
def remove_node(node_id: int):
    """删除指定节点"""

    deleted = delete_node(node_id)

    if not deleted:
        raise HTTPException(
            status_code=404,
            detail="节点不存在"
        )

    return {
        "message": "节点删除成功",
        "id": node_id
    }

# TCP 节点连通性测试接口
@app.post("/api/nodes/{node_id}/test-connection")
def test_node_connection(node_id: int):
    """测试指定节点的 TCP 端口是否可以连接"""

    # 查询节点
    nodes = get_nodes()

    node = next(
        (item for item in nodes if item["id"] == node_id),
        None
    )

    # 节点不存在
    if node is None:
        raise HTTPException(
            status_code=404,
            detail="节点不存在"
        )

    address = node["address"]
    port = node["port"]

    # 记录开始时间
    start_time = time.perf_counter()

    try:
        # 尝试建立 TCP 连接，最多等待 3 秒
        with socket.create_connection(
            (address, port),
            timeout=3
        ):
            pass

        # 计算连接耗时
        latency_ms = round(
            (time.perf_counter() - start_time) * 1000,
            2
        )

        return {
            "node_id": node_id,
            "success": True,
            "message": "TCP 连接成功",
            "address": address,
            "port": port,
            "latency_ms": latency_ms
        }

    except (OSError, TimeoutError) as error:
        return {
            "node_id": node_id,
            "success": False,
            "message": str(error),
            "address": address,
            "port": port,
            "latency_ms": None
        }

@app.post("/api/nodes/{node_id}/generate-config")
def generate_node_config_api(node_id: int):
    """生成指定节点的 Xray 配置"""

    from backend.config_generator import (
        generate_config_for_node,
        save_config_to_file
    )

    try:
        # 根据节点 ID 生成配置
        config = generate_config_for_node(node_id)

        # 保存配置文件
        file_path = save_config_to_file(
            config,
            filename=f"node_{node_id}.json"
        )

        # 调用 Xray 检查配置
        result = subprocess.run(
            [
                "/usr/local/bin/xray",
                "run",
                "-test",
                "-config",
                str(file_path)
            ],
            capture_output=True,
            text=True,
            timeout=15
        )

        # 如果检查失败，返回错误信息
        if result.returncode != 0:
            raise HTTPException(
                status_code=400,
                detail=f"Xray 配置检查失败：{result.stderr}"
            )

        return {
            "message": "配置生成成功",
            "node_id": node_id,
            "file_path": str(file_path),
            "validation": "passed",
            "validation_output": result.stdout.strip(),
            "config": config
        }

    except ValueError as error:
        raise HTTPException(
            status_code=404,
            detail=str(error)
        )

@app.post("/api/nodes/{node_id}/apply")
def apply_node_config(node_id: int):
    """生成并应用指定节点的 Xray 配置"""

    from backend.config_generator import (
        generate_config_for_node,
        save_config_to_file
    )

    try:
        # 生成节点配置
        config = generate_config_for_node(node_id)

        # 保存配置文件
        file_path = save_config_to_file(
            config,
            filename=f"node_{node_id}.json"
        )

        # 应用配置
        apply_result = subprocess.run(
            [
                "sudo",
                "-n",
                "/usr/local/bin/xray-manager-config",
                "apply",
                str(file_path)
            ],
            capture_output=True,
            text=True,
            timeout=20
        )

        if apply_result.returncode != 0:
            raise HTTPException(
                status_code=400,
                detail=(
                    "Xray 配置应用失败："
                    + (apply_result.stdout + apply_result.stderr).strip()
                )
            )

        # 重启 Xray
        restart_result = subprocess.run(
            [
                "sudo",
                "-n",
                "/usr/bin/systemctl",
                "restart",
                "xray"
            ],
            capture_output=True,
            text=True,
            timeout=20
        )

        if restart_result.returncode != 0:
            # 重启失败，尝试恢复旧配置
            subprocess.run(
                [
                    "sudo",
                    "-n",
                    "/usr/local/bin/xray-manager-config",
                    "restore"
                ],
                capture_output=True,
                text=True,
                timeout=20
            )

            subprocess.run(
                [
                    "sudo",
                    "-n",
                    "/usr/bin/systemctl",
                    "restart",
                    "xray"
                ],
                capture_output=True,
                text=True,
                timeout=20
            )

            raise HTTPException(
                status_code=500,
                detail="Xray 重启失败，已尝试恢复旧配置"
            )

        # 检查 Xray 服务状态
        status_result = subprocess.run(
            [
                "/usr/bin/systemctl",
                "is-active",
                "xray"
            ],
            capture_output=True,
            text=True,
            timeout=10
        )

        if status_result.stdout.strip() != "active":
            raise HTTPException(
                status_code=500,
                detail="Xray 重启后未处于运行状态"
            )

        set_setting("active_node_id", node_id)

        return {
            "message": "节点配置应用成功",
            "node_id": node_id,
            "file_path": str(file_path),
            "status": "active"
        }

    except ValueError as error:
        raise HTTPException(
            status_code=404,
            detail=str(error)
        )

# 查询 Xray 服务状态
@app.get("/api/xray/status")
@app.get("/api/xray/active-node")
def get_active_node():
    active_node_id = get_setting("active_node_id")

    if active_node_id is None:
        return {
            "active": False,
            "node": None
        }

    nodes = get_nodes()

    for node in nodes:
        if node["id"] == int(active_node_id):
            return {
                "active": True,
                "node": node
            }

    return {
        "active": False,
        "node": None
    }
def get_xray_status():
    import subprocess

    result = subprocess.run(
        ["systemctl", "is-active", "xray"],
        capture_output=True,
        text=True
    )

    return {
        "service": "xray",
        "status": result.stdout.strip()
    }

# 启动 Xray 服务
@app.post("/api/xray/start")
def start_xray():
    result = subprocess.run(
        ["sudo", "-n", "/usr/bin/systemctl", "start", "xray"],
        capture_output=True,
        text=True
    )

    if result.returncode != 0:
        return {
            "service": "xray",
            "action": "start",
            "status": "failed",
            "message": result.stderr.strip()
        }

    return {
        "service": "xray",
        "action": "start",
        "status": "success",
        "message": "Xray 启动命令执行成功"
    }

# 停止 Xray 服务
@app.post("/api/xray/stop")
def stop_xray():
    result = subprocess.run(
        ["sudo", "-n", "/usr/bin/systemctl", "stop", "xray"],
        capture_output=True,
        text=True
    )

    if result.returncode != 0:
        return {
            "service": "xray",
            "action": "stop",
            "status": "failed",
            "message": result.stderr.strip()
        }

    return {
        "service": "xray",
        "action": "stop",
        "status": "success",
        "message": "Xray 停止命令执行成功"
    }

# 重启 Xray 服务
@app.post("/api/xray/restart")
def restart_xray():
    result = subprocess.run(
        ["sudo", "-n", "/usr/bin/systemctl", "restart", "xray"],
        capture_output=True,
        text=True
    )

    if result.returncode != 0:
        return {
            "service": "xray",
            "action": "restart",
            "status": "failed",
            "message": result.stderr.strip()
        }

    return {
        "service": "xray",
        "action": "restart",
        "status": "success",
        "message": "Xray 重启命令执行成功"
    }