import sqlite3

from backend.database import DB_PATH


def get_setting(key):
    """获取一个设置值"""

    conn = sqlite3.connect(DB_PATH)

    cursor = conn.execute(
        "SELECT value FROM settings WHERE key = ?",
        (key,)
    )

    row = cursor.fetchone()

    conn.close()

    if row is None:
        return None

    return row[0]


def set_setting(key, value):
    """保存一个设置值"""

    conn = sqlite3.connect(DB_PATH)

    conn.execute(
        """
        INSERT OR REPLACE INTO settings (key, value)
        VALUES (?, ?)
        """,
        (key, str(value))
    )

    conn.commit()
    conn.close()