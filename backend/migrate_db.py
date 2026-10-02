import sqlite3

from backend.database import DB_PATH


def migrate_nodes():
    conn = sqlite3.connect(DB_PATH)

    try:
        # 获取当前数据表的字段
        rows = conn.execute(
            "PRAGMA table_info(nodes)"
        ).fetchall()

        existing_columns = {
            row[1] for row in rows
        }

        # 需要新增的字段
        new_columns = {
            "uuid": "TEXT",
            "network": "TEXT DEFAULT 'tcp'",
            "security": "TEXT DEFAULT 'none'",
            "path": "TEXT DEFAULT ''",
            "server_name": "TEXT DEFAULT ''",
        }

        # 逐个检查并添加字段
        for column, definition in new_columns.items():
            if column not in existing_columns:
                conn.execute(
                    f"ALTER TABLE nodes ADD COLUMN "
                    f"{column} {definition}"
                )
                print(f"新增字段：{column}")
            else:
                print(f"字段已存在：{column}")

        conn.commit()

        print("数据库迁移完成")

    finally:
        conn.close()


if __name__ == "__main__":
    migrate_nodes()