import sqlite3
from pathlib import Path

# 获取项目根目录
BASE_DIR = Path(__file__).resolve().parent.parent

# 数据库文件路径
DB_PATH = BASE_DIR / "data" / "xray.db"


# 初始化数据库
def init_db():
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)

    conn = sqlite3.connect(DB_PATH)

    # 创建节点数据表
    conn.execute("""
        CREATE TABLE IF NOT EXISTS nodes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            protocol TEXT NOT NULL,
            address TEXT NOT NULL,
            port INTEGER NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)

    conn.commit()
    conn.close()

    print("数据库初始化成功")
    print(f"数据库路径：{DB_PATH}")
    print("节点数据表 nodes 已创建")


if __name__ == "__main__":
    init_db()