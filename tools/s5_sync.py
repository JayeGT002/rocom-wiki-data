#!/usr/bin/env python3
"""把 WIKI 的 S5 赛季数据同步到本地：生成 S5Season.lua，并追加到图鉴 Excel。

S5 起 WIKI 改用「按赛季压缩模块」：模块:精灵图鉴/S5/配置 指向 数据/{精灵,辅助,...}，
内容为 dragon-tuples-1 编码（字段名表 + [字段下标, 值] 元组）。本脚本负责解码。

用法:
    python3 tools/s5_sync.py --season        # 只生成 S5Season.lua
    python3 tools/s5_sync.py --xlsx          # 只追加 Excel 行
    python3 tools/s5_sync.py                 # 两者都做
    python3 tools/s5_sync.py --xlsx --dry-run # 只打印将要追加的行

依赖: 解析用标准库；写 Excel 需要 openpyxl（用 DSH 自带 Python 运行即可）。
"""

import argparse
import datetime as dt
import json
import os
import re
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from luatab import array, lua_literal, parse_lua  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S5_DIR = os.path.join(ROOT, "data", "wiki_modules", "精灵图鉴", "S5")
XLSX = os.path.join(ROOT, "data", "spreadsheets", "洛克王国世界图鉴Lite.xlsx")

EGG_GROUPS = {
    1: "未发现", 2: "巨灵组", 3: "两栖组", 4: "昆虫组", 5: "天空组",
    6: "动物组", 7: "妖精组", 8: "植物组", 9: "拟人组", 10: "软体组",
    11: "大地组", 12: "魔力组", 13: "海洋组", 14: "飞龙组", 15: "机械组",
}

SEASON_LABELS = {
    "none": "常驻精灵", "S1": "S1 暗夜拾光", "S2": "S2 狂欢怪谈",
    "S3": "S3 铅字幻梦", "S4": "S4月涌狂想", "S5": "S5 圣龙宝藏",
}


def decode_packed(packed, object_tag=1, array_tag=2):
    """解码 dragon-tuples-1：{codec, 字段名表, 数据}。"""
    codec = packed[1]
    if codec != "dragon-tuples-1":
        raise ValueError(f"不支持的赛季编码: {codec!r}")
    fields = {k: v for k, v in packed[2].items() if isinstance(k, int)}

    def dec(value):
        if not isinstance(value, dict):
            return value
        tag = value.get(1)
        if tag == object_tag:
            out = {}
            for _, entry in sorted(value[2].items()):
                if not isinstance(entry, dict):
                    continue
                out[fields[entry[1]]] = dec(entry[2])
            return out
        if tag == array_tag:
            return [dec(child) for _, child in sorted(value[2].items())]
        # 空表 / 非标记表按数组处理
        return [dec(child) for _, child in sorted(value.items(), key=lambda kv: kv[0])]

    return dec(packed[3])


def load_s5():
    config = parse_lua(open(os.path.join(S5_DIR, "配置.lua"), encoding="utf-8").read())
    season = config["seasons"][1] if isinstance(config["seasons"], dict) else config["seasons"][0]
    modules = season["modules"]
    object_tag = season.get("object_tag", 1)
    array_tag = season.get("array_tag", 2)

    def shard(key):
        path = os.path.join(S5_DIR, "数据", modules[key] + ".lua")
        return decode_packed(parse_lua(open(path, encoding="utf-8").read()), object_tag, array_tag)

    return config, shard("Roster"), shard("Aux"), shard("Arts"), shard("Gifts")


def build_chains(aux):
    chains = {}
    aliases = aux.get("LegacyEvolutionAliases") or {}
    for evo_id, rows in (aux.get("Evolutions") or {}).items():
        rows = array(rows) if isinstance(rows, dict) else rows
        if not rows:
            continue
        chain = rows[0].get("chain") or []
        chain = array(chain) if isinstance(chain, dict) else chain
        if chain:
            chains[evo_id] = chain
    for old, new in aliases.items():
        if new in chains:
            chains[old] = chains[new]
    return chains


def family_name(record, chains):
    chain = chains.get(record.get("evolution_id"))
    if chain:
        return str(chain[0].get("name")) + "家族"
    return str(record.get("name")) + "家族"


def classify_direct(record):
    """按获取方式判定；无获取信息返回 None，交给同进化链继承。"""
    num = str(record.get("number"))
    if num in ("245", "254"):
        return "典藏精灵"
    text = []
    for egg in array((record.get("ecology") or {}).get("eggs") or []):
        text.append(str(egg.get("description", "")))
        text.extend(str(s) for s in array(egg.get("sources") or []))
    blob = " ".join(text)
    if "赛季作业" in blob:
        return "传说精灵"
    if "通行证" in blob or "闪耀契约" in blob:
        return "通行证精灵"
    if "代币商店" in blob or "挑战课题" in blob:
        return "赛季奇遇"
    if "活动" in blob:
        return "活动限定"
    return None


def classify_roster(roster):
    direct = {pid: classify_direct(pet) for pid, pet in roster.items()}
    cats = {pid: cat for pid, cat in direct.items() if cat}
    for pid in roster:
        if pid in cats:
            continue
        pet = roster[pid]
        peers = [cats[q] for q, other in roster.items()
                 if q in cats and other.get("evolution_id") == pet.get("evolution_id")]
        if peers:
            cats[pid] = peers[0]
        elif pet.get("is_lord_evolution"):
            cats[pid] = "典藏精灵"
        else:
            cats[pid] = "赛季奇遇"
    return cats


def parse_range(text):
    m = re.match(r"([\d.]+)\s*[~-]\s*([\d.]+)", str(text or ""))
    if not m:
        return None, None
    return float(m.group(1)), float(m.group(2))


def num(value):
    if value is None or value == "":
        return None
    if isinstance(value, float) and value.is_integer():
        return int(value)
    return value


def gender_text(record):
    g = record.get("gender_ratio")
    if not isinstance(g, dict):
        return None
    return f"{g.get('female')}:{g.get('male')}"


def make_row(record, family, season, category):
    types = [str(t).replace("系", "") for t in array(record.get("types") or [])]
    eggs = [EGG_GROUPS.get(g, "") for g in array(record.get("egg_group") or [])]
    hmin, hmax = parse_range(record.get("height"))
    wmin, wmax = parse_range(record.get("weight"))
    egg_size = record.get("egg_size") or {}
    starlight = record.get("starlight")
    gold = starlight * 75 if isinstance(starlight, (int, float)) else None
    return [
        int(record["number"]),
        record.get("title") or record.get("name"),
        family,
        "/".join(types),
        num(starlight),
        num(gold),
        "/".join(eggs),
        season,
        category,
        eggs[0] if eggs else "",
        eggs[1] if len(eggs) > 1 else "",
        types[0] if types else "",
        types[1] if len(types) > 1 else "",
        gender_text(record),
        num(hmax), num(hmin),
        num(wmax), num(wmin),
        num(egg_size.get("min")) if egg_size.get("min") is not None else "-",
        num(egg_size.get("max")) if egg_size.get("max") is not None else "-",
    ]


def load_catalog_rows():
    """从旧版 Catalog 里取 467/468（上次同步后才新增，属于 S4 末期的活动精灵）。"""
    cat = parse_lua(open(os.path.join(ROOT, "data/wiki_modules/Pets/data/Catalog.lua"), encoding="utf-8").read())
    chains = build_chains({"Evolutions": parse_lua(open(
        os.path.join(ROOT, "data/wiki_modules/Pets/data/Evolutions.lua"), encoding="utf-8").read())})
    rows = []
    for _, pet in cat.items():
        if str(pet.get("number")) not in ("467", "468"):
            continue
        rows.append(make_row(pet, family_name(pet, chains), "S4月涌狂想", "活动限定"))
    return rows


def build_rows():
    config, roster, aux, _, _ = load_s5()
    roster = {k: v for k, v in roster.items() if v.get("number")}
    for pid, fields in read_existing_fields().items():
        if pid in roster:
            roster[pid].update(fields)
    chains = build_chains(aux)
    cats = classify_roster(roster)
    season_label = f"S5 {config['current']['name']}"
    rows = load_catalog_rows()
    for pid, pet in sorted(roster.items(), key=lambda kv: (int(kv[1]["number"]), kv[0])):
        rows.append(make_row(pet, family_name(pet, chains), season_label, cats[pid]))
    return rows, roster


SEASON_PATH = os.path.join(ROOT, "data", "seasons", "S5Season.lua")
MANUAL_KEYS = ("starlight", "review_gold", "gender_ratio")


def read_existing_fields():
    """读取现有 S5Season.lua 里手工维护的 starlight/review_gold。"""
    if not os.path.exists(SEASON_PATH):
        return {}
    old = parse_lua(open(SEASON_PATH, encoding="utf-8").read())
    kept = {}
    for pid, pet in old.items():
        if not isinstance(pet, dict):
            continue
        fields = {k: pet[k] for k in MANUAL_KEYS if pet.get(k) is not None}
        if fields:
            kept[pid] = fields
    return kept


def write_season(roster):
    manual = read_existing_fields()
    header = [
        "-- S5 圣龙宝藏 赛季新增/改版精灵数据（对应图鉴 Excel 的 S5 行）",
        "-- 来源: 洛克王国世界WIKI 模块:精灵图鉴/S5/数据/精灵 + /数据/辅助（dragon-tuples-1 解码）",
        "-- 范围: 图鉴 245/254（首领化新形态）与 469-493，共 29 个形态",
        "-- 维护: starlight / review_gold / gender_ratio 为手工字段；重新同步时保留",
        "-- 口径: review_gold = 星光值 ×50（数据仓口径）；站点展示/实测金币按 ×75 换算",
        "-- 约定: 首领化形态（245、254、超能阿布）统一按星光值 80 计",
        "-- 版权: 数据来自洛克王国世界WIKI，遵循 CC BY-NC-SA 4.0",
        "",
        "return {",
    ]
    lines = []
    for pid, pet in sorted(roster.items(), key=lambda kv: (int(kv[1]["number"]), kv[0])):
        merged = {**pet, **manual.get(pid, {})}
        lines.append(f"{pid}={lua_literal(merged)},")
    out = "\n".join(header + lines + ["}", ""])
    with open(SEASON_PATH, "w", encoding="utf-8", newline="") as fh:
        fh.write(out)
    print(f"已生成 {SEASON_PATH}（{len(roster)} 条，{len(out.encode())} 字节；保留手工字段 {len(manual)} 条）")
    validate_season()
    return SEASON_PATH


def validate_season():
    data = parse_lua(open(SEASON_PATH, encoding="utf-8").read())
    filled = [(pid, p) for pid, p in data.items() if p.get("starlight") is not None]
    missing = [p for p in data.values() if p.get("starlight") is None]
    bad = [(pid, p["starlight"], p.get("review_gold"))
           for pid, p in filled if p.get("review_gold") != p["starlight"] * 50]
    print(f"星光值进度: {len(filled)}/{len(data)}；review_gold 口径异常: {len(bad)}")
    if bad:
        for item in bad:
            print("  口径异常:", item)
    if missing:
        nums = sorted({int(p["number"]) for p in missing})
        print("  待补编号:", ", ".join(str(n) for n in nums))


S4_MANUAL = {
    # 466 果实立方人在 Catalog 里没有 starlight/review_gold；星光值取既有 Excel 的 60，
    # 洛克贝按 Catalog 统一口径（星光值 ×50）补算为 3000。
    "pet_000622": {"starlight": 60, "review_gold": 3000},
}


def write_s4():
    """从当前 Catalog 重新生成 S4Season.lua（443-468）。"""
    cat = parse_lua(open(os.path.join(ROOT, "data/wiki_modules/Pets/data/Catalog.lua"), encoding="utf-8").read())
    picks = {pid: pet for pid, pet in cat.items() if 443 <= int(pet.get("number", 0)) <= 468}
    for pid, extra in S4_MANUAL.items():
        if pid in picks:
            picks[pid] = {**picks[pid], **extra}
    header = [
        "-- S4 月涌狂想 赛季精灵数据（与 洛克王国世界图鉴Lite.xlsx 对齐）",
        "-- 来源: 洛克王国世界WIKI Module:Pets/data/Catalog.lua（2026-11-14 复核）",
        "-- 范围: 图鉴 443-468，共 26 个编号 / 26 个形态",
        "-- 字段: 取自 Catalog；466 的星光值来自既有 Excel（Catalog 缺失），review_gold 按 ×50 补算",
        "-- 版权: 数据来自洛克王国世界WIKI + 手工补全, 遵循 CC BY-NC-SA 4.0",
        "",
        "return {",
    ]
    lines = []
    for pid, pet in sorted(picks.items(), key=lambda kv: (int(kv[1]["number"]), kv[0])):
        lines.append(f"{pid}={lua_literal(pet)},")
    out = "\n".join(header + lines + ["}", ""])
    path = os.path.join(ROOT, "data", "seasons", "S4Season.lua")
    with open(path, "w", encoding="utf-8", newline="") as fh:
        fh.write(out)
    print(f"已生成 {path}（{len(picks)} 条，{len(out.encode())} 字节）")


def append_xlsx(rows, dry_run=False):
    try:
        import openpyxl
    except ImportError:
        sys.exit("需要 openpyxl：请用 DSH 自带 Python 运行，例如 "
                 "/Users/jayegt002/.dsh/dsh-runtimes/dsh-primary-runtime/dependencies/python/bin/python3")
    from openpyxl.styles import Alignment

    wb = openpyxl.load_workbook(XLSX)
    ws = wb["工作表1"]
    existing = set()
    for r in range(2, ws.max_row + 1):
        n = ws.cell(r, 1).value
        t = ws.cell(r, 2).value
        if n is None:
            continue
        existing.add((int(n), str(t)))

    pending = [row for row in rows if (row[0], str(row[1])) not in existing]
    print(f"现有数据行: {len(existing)}，待追加: {len(pending)}（候选 {len(rows)}）")
    if dry_run:
        for row in pending:
            print("追加", row)
        for row in rows:
            if (row[0], str(row[1])) in existing:
                print("更新候选", row[:6])
        return
    if not pending and not rows:
        print("没有需要追加/更新的行，跳过。")
        return

    backup = f"/tmp/洛克王国世界图鉴Lite.xlsx.bak-{dt.datetime.now():%Y%m%d-%H%M%S}"
    shutil.copy2(XLSX, backup)
    print("备份:", backup)

    center = Alignment(horizontal="center", vertical="center")
    for row in sorted(pending, key=lambda r: r[0]):
        number = row[0]
        # 插到「最后一个编号 <= number」的行之后，保持按编号排序
        insert_at = 2
        for r in range(2, ws.max_row + 1):
            v = ws.cell(r, 1).value
            if v is not None and isinstance(v, (int, float)) and int(v) <= number:
                insert_at = r + 1
        ws.insert_rows(insert_at)
        for col, value in enumerate(row, start=1):
            cell = ws.cell(insert_at, col, value)
            cell.alignment = center
        print(f"  插入第 {insert_at} 行: {number} {row[1]}")

    # 已存在的 S5 行：同步星光值 / 基础洛克贝（×75）
    index = {}
    for r in range(2, ws.max_row + 1):
        n = ws.cell(r, 1).value
        t = ws.cell(r, 2).value
        if n is not None:
            index[(int(n), str(t))] = r
    updated = 0
    for row in rows:
        r = index.get((row[0], str(row[1])))
        if r is None:
            continue
        if ws.cell(r, 5).value != row[4] or ws.cell(r, 6).value != row[5]:
            ws.cell(r, 5, row[4]).alignment = center
            ws.cell(r, 6, row[5]).alignment = center
            updated += 1
    print(f"更新已有行: {updated}")

    wb.save(XLSX)
    print("已保存", XLSX)


def validate(rows):
    wb = None
    try:
        import openpyxl
        wb = openpyxl.load_workbook(XLSX, data_only=True)
    except ImportError:
        return
    ws = wb["工作表1"]
    seen = {}
    for r in range(2, ws.max_row + 1):
        n = ws.cell(r, 1).value
        t = ws.cell(r, 2).value
        if n is None:
            continue
        seen.setdefault((int(n), str(t)), 0)
        seen[(int(n), str(t))] += 1
    missing = [row for row in rows if (row[0], str(row[1])) not in seen]
    dup = {k: v for k, v in seen.items() if v > 1}
    print(f"校验: 数据行 {ws.max_row - 1}，新增缺失 {len(missing)}，重复键 {len(dup)}")
    for row in missing:
        print("  缺失:", row[:3])
    for k, v in dup.items():
        print("  重复:", k, v)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--season", action="store_true", help="生成 S5Season.lua")
    ap.add_argument("--s4", action="store_true", help="按当前 Catalog 重建 S4Season.lua（443-468）")
    ap.add_argument("--xlsx", action="store_true", help="追加 Excel 行")
    ap.add_argument("--dry-run", action="store_true", help="只打印，不写文件")
    args = ap.parse_args()
    if args.s4 and not (args.season or args.xlsx):
        if not args.dry_run:
            write_s4()
        return
    do_season = args.season or not args.xlsx
    do_xlsx = args.xlsx or not args.season

    rows, roster = build_rows()
    if do_season and not args.dry_run:
        write_season(roster)
    if do_xlsx:
        append_xlsx(rows, dry_run=args.dry_run)
        if not args.dry_run:
            validate(rows)


if __name__ == "__main__":
    main()
