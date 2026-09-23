"""Shared Lua-source adapters and normalized pet records."""

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "data"
CATALOG = DATA_DIR / "wiki_modules/Pets/data/Catalog.lua"
SEASONS_DIR = DATA_DIR / "seasons"

TOKEN_RE = re.compile(
    r"(?P<space>\s+)|(?P<comment>--[^\n]*)|"
    r'(?P<string>"(?:\\.|[^"\\])*")|'
    r"(?P<number>-?(?:\d+\.\d*|\.\d+|\d+)(?:[eE][+-]?\d+)?)|"
    r"(?P<identifier>[A-Za-z_][A-Za-z0-9_]*)|(?P<symbol>[{}=\[\],;])"
)


class LuaTableParser:
    """Parse the literal table subset used by the checked-in Wiki data."""

    def __init__(self, text):
        self.tokens = []
        pos = 0
        while pos < len(text):
            match = TOKEN_RE.match(text, pos)
            if not match:
                raise ValueError(f"无法解析 Lua 数据，位置 {pos}: {text[pos:pos + 24]!r}")
            pos = match.end()
            kind = match.lastgroup
            if kind not in ("space", "comment"):
                self.tokens.append((kind, match.group(kind)))
        self.index = 0

    def peek(self, value=None):
        if self.index >= len(self.tokens):
            return False if value is not None else None
        token = self.tokens[self.index]
        return token[1] == value if value is not None else token

    def take(self, value=None):
        token = self.peek()
        if token is None or (value is not None and token[1] != value):
            got = "文件结束" if token is None else repr(token[1])
            raise ValueError(f"Lua 数据语法错误：预期 {value!r}，实际 {got}")
        self.index += 1
        return token

    def parse(self):
        if self.peek("return"):
            self.take("return")
        value = self.parse_value()
        if self.index != len(self.tokens):
            raise ValueError(f"Lua 数据末尾存在未解析内容：{self.peek()[1]!r}")
        if not isinstance(value, dict):
            raise ValueError("Lua 数据根节点必须是 table")
        return value

    def parse_value(self):
        token = self.peek()
        if token is None:
            raise ValueError("Lua 数据意外结束")
        kind, value = token
        if value == "{":
            return self.parse_table()
        if kind == "string":
            self.take()
            return json.loads(value)
        if kind == "number":
            self.take()
            return float(value) if any(char in value for char in ".eE") else int(value)
        if kind == "identifier":
            self.take()
            if value == "true":
                return True
            if value == "false":
                return False
            if value == "nil":
                return None
            raise ValueError(f"不支持的 Lua 值: {value}")
        raise ValueError(f"不支持的 Lua token: {value!r}")

    def parse_table(self):
        self.take("{")
        mapping = {}
        sequence = []
        has_named_keys = False
        while not self.peek("}"):
            if self.peek() is None:
                raise ValueError("Lua table 缺少结束符 '}'")
            token = self.peek()
            following = self.tokens[self.index + 1] if self.index + 1 < len(self.tokens) else None
            if token[0] == "identifier" and following and following[1] == "=":
                key = self.take()[1]
                self.take("=")
                mapping[key] = self.parse_value()
                has_named_keys = True
            elif token[1] == "[":
                self.take("[")
                key = self.parse_value()
                self.take("]")
                self.take("=")
                mapping[key] = self.parse_value()
                has_named_keys = True
            else:
                value = self.parse_value()
                sequence.append(value)
                if has_named_keys:
                    mapping[len(sequence)] = value
            if self.peek(",") or self.peek(";"):
                self.take()
            elif not self.peek("}"):
                raise ValueError("Lua table 字段之间缺少逗号")
        self.take("}")
        return mapping if has_named_keys else sequence


def season_sources():
    """Discover season files without hard-coding the current latest season."""
    if not SEASONS_DIR.is_dir():
        return []
    found = []
    for path in SEASONS_DIR.glob("S*Season.lua"):
        match = re.fullmatch(r"S(\d+)Season\.lua", path.name)
        if match:
            found.append((int(match.group(1)), f"S{match.group(1)}", path))
    return sorted(found)


def parse_source(path, source_name, season=None):
    """Load one independent Lua source and normalize its pet records."""
    try:
        raw = LuaTableParser(path.read_text(encoding="utf-8")).parse()
    except OSError as exc:
        raise ValueError(f"无法读取数据源 {path}: {exc}") from exc

    records = {}
    for key, item in raw.items():
        if not (isinstance(key, str) and re.fullmatch(r"pet_\d+", key)):
            continue
        if not isinstance(item, dict):
            raise ValueError(f"{path}: {key} 不是 Lua table")
        number = item.get("number")
        if number is None:
            continue
        egg_size = item.get("egg_size") or {}
        egg_min = egg_size.get("min") if isinstance(egg_size, dict) else None
        egg_max = egg_size.get("max") if isinstance(egg_size, dict) else None
        records[key] = {
            "id": key,
            "number": str(number).zfill(3),
            "title": item.get("title") or item.get("name") or key,
            "name": item.get("name"),
            "stage": item.get("stage"),
            "starlight": item.get("starlight"),
            "review_gold": item.get("review_gold"),
            "egg_group": item.get("egg_group") or [],
            "egg_min": egg_min,
            "egg_max": egg_max,
            "types": item.get("types") or [],
            "height": item.get("height"),
            "weight": item.get("weight"),
            "gender_ratio": item.get("gender_ratio"),
            "category": item.get("class"),
            "season": season,
            "source": source_name,
            "attributes": item,
        }
    return records


def merge_tables(base, override):
    """Merge season-maintained fields without changing either source file."""
    if isinstance(base, dict) and isinstance(override, dict):
        result = dict(base)
        for key, value in override.items():
            result[key] = merge_tables(result[key], value) if key in result else value
        return result
    if isinstance(base, list) and isinstance(override, list):
        return override if override else base
    return override


def load_pets(source="all", season=None):
    """Route each source through its adapter, then combine by stable pet ID.

    Season-specific values take precedence at query time; the raw source files
    remain separate and are never rewritten.
    """
    sources = []
    if source in ("all", "catalog"):
        sources.append(("Wiki Catalog", None, CATALOG))
    if source in ("all", "seasons"):
        sources.extend((label, label, path) for _, label, path in season_sources())
    if season:
        sources = [entry for entry in sources if entry[1] == season]

    pets = {}
    for label, season_name, path in sources:
        for pet_id, record in parse_source(path, label, season_name).items():
            current = pets.setdefault(pet_id, {"id": pet_id, "sources": []})
            if label not in current["sources"]:
                current["sources"].append(label)
            for field, value in record.items():
                current.setdefault(field, None)
                if field == "attributes" and isinstance(value, dict):
                    current[field] = merge_tables(current[field] or {}, value)
                    continue
                if field not in ("id", "source") and value not in (None, "", []):
                    current[field] = value
    return pets
