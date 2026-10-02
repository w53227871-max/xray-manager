import sqlite3
from backend.database import DB_PATH
from backend.utils import generate_uuid


def create_node(
    name, protocol, address, port,
    network="tcp", security="none", server_name="", path=""
):
    """向数据库添加一个节点"""

    conn = sqlite3.connect(DB_PATH)

    # 只有 VLESS 节点才自动生成 UUID
    node_uuid = generate_uuid() if protocol.lower() == "vless" else None

    cursor = conn.execute(
        """
        INSERT INTO nodes (
            name, protocol, address, port, uuid,
            network, security, server_name, path
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            name, protocol, address, port, node_uuid,
            network, security, server_name, path
        )
    )

    node_id = cursor.lastrowid

    conn.commit()
    conn.close()

    return node_id

def get_nodes():
    """查询所有节点"""

    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row

    rows = conn.execute(
        "SELECT * FROM nodes ORDER BY id DESC"
    ).fetchall()

    nodes = [dict(row) for row in rows]

    conn.close()

    return nodes

def update_node(
    node_id, name, protocol, address, port,
    network="tcp", security="none", server_name="", path=""
):
    """根据节点 ID 修改节点信息"""

    conn = sqlite3.connect(DB_PATH)

    cursor = conn.execute(
        """
        UPDATE nodes
        SET name = ?, protocol = ?, address = ?, port = ?,
            network = ?, security = ?, server_name = ?, path = ?
        WHERE id = ?
        """,
        (
            name, protocol, address, port,
            network, security, server_name, path, node_id
        )
    )

    conn.commit()

    updated = cursor.rowcount > 0

    conn.close()

    return updated

def delete_node(node_id):
    """根据节点 ID 删除节点"""

    conn = sqlite3.connect(DB_PATH)

    cursor = conn.execute(
        "DELETE FROM nodes WHERE id = ?",
        (node_id,)
    )

    conn.commit()

    deleted = cursor.rowcount > 0

    conn.close()

    return deleted