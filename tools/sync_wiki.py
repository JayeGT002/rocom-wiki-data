#!/usr/bin/env python3
"""用 MediaWiki API 同步 洛克王国世界 WIKI 的图鉴数据模块。

用法:
    python3 tools/sync_wiki.py            # 只比对，不写文件
    python3 tools/sync_wiki.py --apply    # 拉取并写入 data/wiki_modules/
    python3 tools/sync_wiki.py --apply --json report.json

说明:
- 2026-11 起该站 api.php 已可直接访问（此前 docs 记录的 WAF 硬拦截已失效）。
- 一次请求批量拿多页内容，避免并发触发风控；失败自动重试。
- 只覆盖显式列出的模块；wiki 上新增的模块需要先加进 MODULE_TITLES。
"""

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API = "https://wiki.biligame.com/nrc/api.php"
UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
      "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "data", "wiki_modules")

# 需要归档的模块标题（站点本地化命名空间为「模块:」，API 也接受 Module:）
PETS = "模块:Pets"
PET_DATA = [
    "Catalog", "Config", "Evolutions", "Handbooks", "History", "Index",
    "Learnsets", "Overview", "SkillStoneTopics", "Skills", "Terms",
    "TrainingReference", "Types",
]
MODULE_TITLES = (
    [PETS]
    + [f"模块:Pets/{name}" for name in
       ("EvolutionConditions", "SeasonConfig", "SeasonData", "Theme")]
    + [f"模块:Pets/data/{name}" for name in PET_DATA]
    + [
        "模块:精灵图鉴/S5/配置",
        "模块:精灵图鉴/S5/数据/精灵",
        "模块:精灵图鉴/S5/数据/辅助",
        "模块:精灵图鉴/S5/数据/技能",
        "模块:精灵图鉴/S5/数据/特性",
        "模块:精灵图鉴/S5/数据/关联",
    ]
)


def api(params: dict) -> dict:
    query = urllib.parse.urlencode({**params, "format": "json", "formatversion": 2})
    req = urllib.request.Request(API + "?" + query, headers={
        "User-Agent": UA,
        "Accept-Language": "zh-CN,zh;q=0.9",
    })
    last = None
    for attempt, delay in enumerate((5, 15, 30)):
        try:
            with urllib.request.urlopen(req, timeout=90) as resp:
                raw = resp.read()
            body = raw.decode("utf-8")
            if len(raw) in range(7300, 7400) and "TencentEdgeOne" in body:
                raise RuntimeError("被 EdgeOne 拦截")
            return json.loads(body)
        except Exception as exc:  # noqa: BLE001 - 统一重试
            last = exc
            if attempt < 2:
                time.sleep(delay)
    raise RuntimeError(f"API 请求失败: {last}")


def fetch_batch(titles: list[str]) -> dict[str, dict]:
    """返回 {标题: {revid, timestamp, size, content}}。"""
    out: dict[str, dict] = {}
    for start in range(0, len(titles), 3):
        chunk = titles[start:start + 3]
        data = api({
            "action": "query",
            "prop": "revisions",
            "rvprop": "ids|timestamp|size|content",
            "rvslots": "main",
            "titles": "|".join(chunk),
        })
        pages = data.get("query", {}).get("pages", [])
        by_title = {p["title"]: p for p in pages}
        for title in chunk:
            page = by_title.get(title)
            if page is None:
                # API 会把不存在的标题规范化后返回，按 missing 处理
                out[title] = {"missing": True}
                continue
            if page.get("missing"):
                out[title] = {"missing": True}
                continue
            rev = page["revisions"][0]
            out[title] = {
                "revid": rev["revid"],
                "timestamp": rev["timestamp"],
                "size": rev["size"],
                "content": rev["slots"]["main"]["content"],
            }
        time.sleep(2.0)
    return out


def title_to_path(title: str) -> str:
    rel = title
    for prefix in ("模块:", "Module:"):
        if rel.startswith(prefix):
            rel = rel[len(prefix):]
            break
    return os.path.join(OUT_DIR, rel + ".lua")


def read_text(path: str) -> str | None:
    try:
        with open(path, encoding="utf-8", newline="") as fh:
            return fh.read()
    except FileNotFoundError:
        return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="写入本地文件")
    ap.add_argument("--json", metavar="PATH", help="把报告写到 JSON 文件")
    args = ap.parse_args()

    print(f"目标: {API}")
    print(f"模块数: {len(MODULE_TITLES)}")
    fetched = fetch_batch(MODULE_TITLES)

    report = []
    counts = {"added": 0, "changed": 0, "same": 0, "missing": 0}
    for title in MODULE_TITLES:
        path = title_to_path(title)
        rel = os.path.relpath(path, ROOT)
        item = fetched.get(title, {"missing": True})
        if item.get("missing"):
            counts["missing"] += 1
            report.append({"title": title, "path": rel, "status": "missing"})
            print(f"[MISS] {rel}")
            continue
        content = item["content"]
        local = read_text(path)
        if local is None:
            status = "added"
        elif local == content:
            status = "same"
        elif local.rstrip("\n") == content.rstrip("\n"):
            status = "changed"
        else:
            status = "changed"
        counts[status] += 1
        report.append({
            "title": title, "path": rel, "status": status,
            "revid": item["revid"], "timestamp": item["timestamp"],
            "remote_size": item["size"], "local_size": len(local.encode()) if local is not None else None,
        })
        flag = {"added": "[NEW ]", "changed": "[DIFF]", "same": "[SAME]"}[status]
        print(f"{flag} {rel}  rev={item['revid']} ts={item['timestamp']} size={item['size']}")

        if args.apply and status in ("added", "changed"):
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w", encoding="utf-8", newline="") as fh:
                fh.write(content)

    print("\n汇总:", ", ".join(f"{k}={v}" for k, v in counts.items()))
    if args.apply:
        print("已写入:", counts["added"] + counts["changed"], "个文件")
    else:
        print("未写入（加 --apply 生效）")
    if args.json:
        with open(args.json, "w", encoding="utf-8") as fh:
            json.dump({
                "api": API, "generated_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
                "counts": counts, "files": report,
            }, fh, ensure_ascii=False, indent=2)
        print("报告:", args.json)
    return 0


if __name__ == "__main__":
    sys.exit(main())
