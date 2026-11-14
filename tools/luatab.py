"""极简 Lua 字面量解析器：解析 WIKI 数据模块的 `return {...}`。

只支持数据模块用到的语法：table / string / number / boolean / nil，
以及 `--` 行注释。不支持函数、运算、长字符串以外的 Lua 语法。
"""

import re


class LuaParser:
    def __init__(self, text):
        self.s = text
        self.i = 0
        self.n = len(text)

    def error(self, msg):
        raise ValueError(f"{msg} at offset {self.i}: {self.s[self.i:self.i + 60]!r}")

    def skip(self):
        while self.i < self.n:
            c = self.s[self.i]
            if c in " \t\r\n":
                self.i += 1
            elif self.s.startswith("--", self.i):
                j = self.s.find("\n", self.i)
                self.i = self.n if j < 0 else j + 1
            else:
                break

    def parse(self):
        self.skip()
        if not self.s.startswith("return", self.i):
            self.error("expected return")
        self.i += 6
        return self.value()

    def value(self):
        self.skip()
        if self.i >= self.n:
            self.error("unexpected EOF")
        c = self.s[self.i]
        if c == "{":
            return self.table()
        if c in "\"'":
            return self.string()
        if self.s.startswith("[[", self.i):
            return self.long_string()
        if c.isdigit() or c == "-":
            return self.number()
        for lit, val in (("true", True), ("false", False), ("nil", None)):
            if self.s.startswith(lit, self.i):
                after = self.s[self.i + len(lit):self.i + len(lit) + 1]
                if not (after.isalnum() or after == "_"):
                    self.i += len(lit)
                    return val
        self.error("bad value")

    def string(self):
        quote = self.s[self.i]
        self.i += 1
        out = []
        escapes = {"n": "\n", "t": "\t", "r": "\r", '"': '"', "'": "'", "\\": "\\"}
        while self.i < self.n:
            c = self.s[self.i]
            if c == "\\":
                self.i += 1
                e = self.s[self.i]
                if e in escapes:
                    out.append(escapes[e])
                    self.i += 1
                elif e == "u":
                    out.append(chr(int(self.s[self.i + 1:self.i + 5], 16)))
                    self.i += 5
                else:
                    out.append(e)
                    self.i += 1
            elif c == quote:
                self.i += 1
                return "".join(out)
            else:
                out.append(c)
                self.i += 1
        self.error("unterminated string")

    def long_string(self):
        self.i += 2
        j = self.s.find("]]", self.i)
        if j < 0:
            self.error("unterminated long string")
        out = self.s[self.i:j]
        self.i = j + 2
        return out

    def number(self):
        m = re.match(r"-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?", self.s[self.i:])
        if not m:
            self.error("bad number")
        raw = m.group(0)
        self.i += len(raw)
        return float(raw) if ("." in raw or "e" in raw.lower()) else int(raw)

    def table(self):
        self.i += 1
        obj = {}
        index = 1
        while True:
            self.skip()
            if self.i >= self.n:
                self.error("unterminated table")
            if self.s[self.i] == "}":
                self.i += 1
                return obj
            if self.s[self.i] == "[":
                self.i += 1
                key = self.value()
                self.skip()
                if self.s[self.i] != "]":
                    self.error("expected ]")
                self.i += 1
                self.skip()
                if self.s[self.i] != "=":
                    self.error("expected =")
                self.i += 1
                obj[key] = self.value()
            else:
                m = re.match(r"[A-Za-z_]\w*", self.s[self.i:])
                if m:
                    k = self.i + len(m.group(0))
                    while k < self.n and self.s[k] in " \t\r\n":
                        k += 1
                    if k < self.n and self.s[k] == "=" and not self.s.startswith("==", k):
                        self.i = k + 1
                        obj[m.group(0)] = self.value()
                    else:
                        obj[index] = self.value()
                        index += 1
                else:
                    obj[index] = self.value()
                    index += 1
            self.skip()
            if self.i < self.n and self.s[self.i] in ",;":
                self.i += 1
            elif self.i < self.n and self.s[self.i] == "}":
                continue
            else:
                self.error("expected , or }")


def parse_lua(text):
    return LuaParser(text).parse()


def array(value):
    """把 table/list 统一转成 list（dict 只取整数键，按序）。"""
    if isinstance(value, list):
        return value
    if isinstance(value, dict):
        return [value[k] for k in sorted(k for k in value if isinstance(k, int))]
    return []


def lua_literal(value, indent=0):
    """把 Python 值序列化成 Lua 字面量，键排序保证输出稳定。"""
    pad = "  " * indent
    if value is None:
        return "nil"
    if value is True:
        return "true"
    if value is False:
        return "false"
    if isinstance(value, (int, float)):
        if isinstance(value, float) and value.is_integer():
            return str(int(value))
        return repr(value)
    if isinstance(value, str):
        out = value.replace("\\", "\\\\").replace('"', '\\"')
        out = out.replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
        return f'"{out}"'
    if isinstance(value, dict):
        keys = list(value)
        ints = sorted(k for k in keys if isinstance(k, int))
        strs = sorted(k for k in keys if not isinstance(k, int))
        if ints and not strs and ints == list(range(1, len(ints) + 1)):
            parts = [lua_literal(value[k], indent + 1) for k in ints]
            return "{" + ",".join(parts) + "}"
        parts = []
        for k in ints + strs:
            if isinstance(k, int):
                parts.append(f"[{k}]={lua_literal(value[k], indent + 1)}")
            elif re.match(r"^[A-Za-z_]\w*$", str(k)) and str(k) not in _LUA_KEYWORDS:
                parts.append(f"{k}={lua_literal(value[k], indent + 1)}")
            else:
                parts.append(f"[{lua_literal(str(k))}]={lua_literal(value[k], indent + 1)}")
        return "{" + ",".join(parts) + "}"
    if isinstance(value, list):
        return "{" + ",".join(lua_literal(v, indent + 1) for v in value) + "}"
    raise TypeError(f"无法序列化: {type(value)!r}")


_LUA_KEYWORDS = {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function",
    "goto", "if", "in", "local", "nil", "not", "or", "repeat", "return",
    "then", "true", "until", "while",
}
