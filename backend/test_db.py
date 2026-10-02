import sqlite3
from pathlib import Path

# 数据库路径
BASE_DIR = Path(__file__).resolve().parent.parent
DB_PATH = BASE_DIR / "data" / "xray.db"


# 连接数据库
conn = sqlite3.connect(DB_PATH)

# 添加一条测试节点
conn.execute(
    """
    INSERT INTO nodes (name, protocol, address, port)
    VALUES (?, ?, ?, ?)
    """,
    ("测试节点", "vless", "example.com", 443)
)

# 保存数据
conn.commit()

print("测试节点添加成功")

# 删除指定节点
conn.execute(
    "DELETE FROM nodes WHERE id = ?",
    (1,)
)

conn.commit()

print("节点删除成功")

# 查询所有节点
cursor = conn.execute("SELECT * FROM nodes")

for row in cursor.fetchall():
    print(row)

# 关闭数据库连接
conn.close()