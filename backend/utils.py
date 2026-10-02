import uuid


def generate_uuid():
    """生成一个新的 UUID"""
    return str(uuid.uuid4())


if __name__ == "__main__":
    print(generate_uuid())