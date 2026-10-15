"""仅供Android Release工作流恢复和清理临时密钥，不读取本地签名配置。"""

import argparse
import base64
import os
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description="Android CI临时签名密钥")
    parser.add_argument("--clean", action="store_true", help="删除本工作流的临时密钥")
    args = parser.parse_args()
    keystore = Path(os.environ["RUNNER_TEMP"]) / "legado-release.jks"
    if args.clean:
        keystore.unlink(missing_ok=True)
        return

    required = ("ANDROID_KEYSTORE_BASE64", "ANDROID_KEYSTORE_PASSWORD", "ANDROID_KEY_ALIAS",
                "ANDROID_KEY_PASSWORD", "ANDROID_SIGNING_CERT_SHA256")
    missing = [key for key in required if not os.environ.get(key)]
    if missing:
        raise SystemExit("缺少签名配置：" + ", ".join(missing))
    try:
        content = base64.b64decode("".join(os.environ["ANDROID_KEYSTORE_BASE64"].split()), validate=True)
    except ValueError:
        raise SystemExit("ANDROID_KEYSTORE_BASE64格式无效。")
    if not content:
        raise SystemExit("发行密钥文件为空。")
    keystore.write_bytes(content)
    keystore.chmod(0o600)
    with Path(os.environ["GITHUB_ENV"]).open("a", encoding="utf-8") as stream:
        stream.write(f"ANDROID_KEYSTORE_PATH={keystore}\n")


if __name__ == "__main__":
    main()
