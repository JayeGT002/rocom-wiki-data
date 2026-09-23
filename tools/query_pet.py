#!/usr/bin/env python3
"""Search the normalized Wiki Catalog and independently maintained seasons."""

import argparse
import json
import re
import sys

from pet_data import load_pets, season_sources


EGG_GROUPS = {
    1: "未发现", 2: "巨灵组", 3: "两栖组", 4: "昆虫组", 5: "天空组",
    6: "动物组", 7: "妖精组", 8: "植物组", 9: "拟人组", 10: "软体组",
    11: "大地组", 12: "魔力组", 13: "海洋组", 14: "飞龙组", 15: "机械组",
}


def display_value(value):
    return "未收录" if value is None or value == "" else str(value)


def format_number(value):
    if value is None:
        return "未收录"
    return str(int(value)) if isinstance(value, float) and value.is_integer() else str(value)


def primary_form(records):
    base = [pet for pet in records if not re.search(r"[（(]", pet["title"])]
    return base[0] if base else records[0]


def main():
    seasons = [label for _, label, _ in season_sources()]
    parser = argparse.ArgumentParser(description="查询归档的洛克王国世界 WIKI 与赛季数据")
    parser.add_argument("q", nargs="+", help="图鉴编号、名称或 pet_id")
    parser.add_argument("--all", action="store_true", help="显示同一图鉴编号下的全部形态")
    parser.add_argument("--source", choices=("all", "catalog", "seasons"), default="all", help="指定数据来源")
    parser.add_argument("--season", choices=seasons, help="仅查询指定赛季 Lua 文件")
    args = parser.parse_args()

    try:
        pets = load_pets(args.source, args.season)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"数据读取失败：{exc}", file=sys.stderr)
        raise SystemExit(2)

    query = " ".join(args.q).strip()
    if query.isdigit():
        number = query.zfill(3)
        results = [pet for pet in pets.values() if pet["number"] == number]
    elif query.lower().startswith("pet_"):
        results = [pet for pet_id, pet in pets.items() if pet_id == query.lower()]
    else:
        results = [pet for pet in pets.values() if query in pet["title"] or query in (pet["name"] or "")]

    if not results:
        print(f"未找到：{query}")
        return

    shown = results if args.all else [primary_form(results)]
    for pet in shown:
        egg_groups = "/".join(EGG_GROUPS.get(group, f"未知蛋组({group})") for group in pet["egg_group"])
        egg_size = f"{format_number(pet['egg_min'])}~{format_number(pet['egg_max'])}"
        attrs = pet["types"] if isinstance(pet["types"], list) else []
        print(
            f"编号{pet['number']} | {pet['title']} | 阶段{display_value(pet['stage'])} | "
            f"星光值{display_value(pet['starlight'])} | 洛克贝{display_value(pet['review_gold'])} | "
            f"蛋组[{egg_groups or '未收录'}] | 蛋大小[{egg_size}] | "
            f"属性{','.join(map(str, attrs)) or '未收录'} | 分类{display_value(pet['category'])} | "
            f"赛季{display_value(pet['season'])} | 数据源[{'+'.join(pet['sources'])}]"
        )


if __name__ == "__main__":
    main()
