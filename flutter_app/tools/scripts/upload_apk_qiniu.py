#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
七牛云 Kodo 上传 APK + version.json（应用内更新用）。
用法：
  python upload_apk_qiniu.py <apk_local_path> <version> [notes]
依赖：pip install qiniu
凭据从 项目文档/cf_upload.env 读取（QINIU_AK / QINIU_SK / bucket=const / domain=m.ebmma.com）。
APK 与 version.json 存于 const 桶的 hermesmb/ 目录（m.ebmma.com 已绑定、永久可用，走 HTTP 明文）。
"""
import os, sys, json, re

# 读取 env 文件里的七牛凭据（不依赖 python-dotenv）
ENV_PATH = os.path.join(
    os.path.dirname(__file__), "..", "..", "..", "..",
    "项目文档", "cf_upload.env"
)
ENV_PATH = os.path.abspath(ENV_PATH)

def load_env(path):
    env = {}
    if not os.path.exists(path):
        return env
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            env[k.strip()] = v.strip()
    return env

ENV = load_env(ENV_PATH)
AK = ENV.get("QINIU_AK", "")
SK = ENV.get("QINIU_SK", "")
BUCKET = ENV.get("QINIU_BUCKET", "const")
# 存到 const 桶的 hermesmb/ 目录（m.ebmma.com 已绑定该桶，走 HTTP 明文绕开自签证书）
KEY_PREFIX = ENV.get("QINIU_KEY_PREFIX", "hermesmb/")
DOMAIN = ENV.get("QINIU_DOMAIN", "m.ebmma.com")

try:
    from qiniu import Auth, put_file
except ImportError:
    sys.exit("请先安装 qiniu SDK: pip install qiniu")

def main():
    if len(sys.argv) < 3:
        sys.exit("用法: python upload_apk_qiniu.py <apk路径> <版本号> [更新说明]")
    apk_path = sys.argv[1]
    version = sys.argv[2].lstrip("vV")
    notes = sys.argv[3] if len(sys.argv) > 3 else ""
    if not os.path.exists(apk_path):
        sys.exit(f"APK 不存在: {apk_path}")
    if not AK or not SK:
        sys.exit("七牛凭据缺失，请检查 项目文档/cf_upload.env 的 QINIU_AK/QINIU_SK")

    q = Auth(AK, SK)
    apk_key = f"{KEY_PREFIX}hermes-agent-mobile-v{version}.apk"
    # 1) 上传 APK
    print(f"[1/2] 上传 APK -> {BUCKET}/{apk_key}")
    token = q.upload_token(BUCKET, apk_key, 3600)
    ret, info = put_file(token, apk_key, apk_path)
    if info.status_code != 200:
        sys.exit(f"APK 上传失败: {info.status_code} {ret}")
    print("     OK:", ret)

    # 2) 写 version.json（同目录 hermesmb/）
    apk_url = f"http://{DOMAIN}/{apk_key}"
    version_json = json.dumps(
        {"version": version, "apk": apk_url, "notes": notes},
        ensure_ascii=False, indent=2,
    ).encode("utf-8")
    vkey = f"{KEY_PREFIX}version.json"
    print(f"[2/2] 上传 version.json -> {BUCKET}/{vkey}")
    token2 = q.upload_token(BUCKET, vkey, 3600)
    ret2, info2 = put_file(token2, vkey, None,
                            data=version_json)
    if info2.status_code != 200:
        sys.exit(f"version.json 上传失败: {info2.status_code} {ret2}")
    print("     OK:", ret2)
    print(f"\n完成！更新源: http://{DOMAIN}/{vkey}")
    print(f"APK 直链: {apk_url}")

if __name__ == "__main__":
    main()
