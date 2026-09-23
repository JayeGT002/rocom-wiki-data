# 简化版本差异发现方法

> 面向 agent 的快速版本检测方案。将"15 文件全量对比"降为"1 文件轻量探针"。

## 核心发现

`Module:Pets/data/Config.lua`（仅 ~4.6KB）内嵌 wiki 的完整版本元数据：

```lua
current_version="s4-2026-09-17"   -- 当前生效版本
versions={
  {current=false,id="s1-2026-05-07",label="S1 赛季 5月7日数据"},
  ...
  {current=false,id="s4-2026-09-10",label="S4 月涌狂想 9月10日数据"},
  {current=true, id="s4-2026-09-17",label="S4 月涌狂想 9月17日数据"}
}
pet_count=621
```

**只需抓取 Config.lua 一个文件，即可判定本地是否过期。**

## 检测流程

```
Step 1: 抓取远程 Config.lua（1 请求，~4.6KB）
Step 2: 提取 current_version 字段
Step 3: 与本地 Config.lua 的 current_version 比对
  ├─ 一致 → 本地已是最新，无需进一步操作
  └─ 不一致 → 触发全量抓取（15 个模块）
```

## 实现示例

```python
import re, subprocess, time

WIKI = "https://wiki.biligame.com/nrc/index.php"
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
LOCAL_CONFIG = "wiki_modules/Pets/data/Config.lua"

def get_version(text: str) -> str:
    m = re.search(r'current_version="([^"]+)"', text)
    return m.group(1) if m else ""

def fetch_config() -> str:
    import urllib.parse
    title = urllib.parse.quote("Module:Pets/data/Config")
    r = subprocess.run(
        ["curl", "-s", "--max-time", "30", "-A", UA,
         f"{WIKI}?title={title}&action=raw"],
        capture_output=True, text=True
    )
    # 拦截页判定
    if len(r.stdout) in range(7300, 7400) and "TencentEdgeOne" in r.stdout:
        raise Exception("被 EdgeOne 拦截")
    return r.stdout

def check_version() -> tuple[bool, str, str]:
    remote = fetch_config()
    local = open(LOCAL_CONFIG, encoding="utf-8").read()
    r_ver = get_version(remote)
    l_ver = get_version(local)
    return (r_ver == l_ver, l_ver, r_ver)

# 使用
is_latest, local_ver, remote_ver = check_version()
if is_latest:
    print(f"本地已是最新版本: {local_ver}")
else:
    print(f"版本不同: 本地={local_ver} → 远程={remote_ver}，需全量抓取")
```

## 效率对比

| 方法 | 请求数 | 传输量 | 耗时 | 适用场景 |
|---|---|---|---|---|
| 全量对比（15 文件） | 15 | ~5.2MB | ~25s（顺序+间隔） | 确认有差异后，需更新数据 |
| **Config.lua 探针** | **1** | **~4.6KB** | **~1s** | 日常巡检/定期检测是否有更新 |
| Config.lua + pet_count | 1 | ~4.6KB | ~1s | 同时检测精灵总数变化 |

## 补充：pet_count 快速变化检测

Config.lua 中的 `pet_count` 字段反映精灵总数。若仅需判断"是否有新增/删除精灵"：

```python
def get_pet_count(text: str) -> int:
    m = re.search(r'pet_count=(\d+)', text)
    return int(m.group(1)) if m else -1
```

`pet_count` 变化 → Catalog 等核心文件有增删，需全量更新。
`pet_count` 不变但 `current_version` 变 → 仅有数值调整/数据富化，仍需全量更新。

**结论：`current_version` 是最优先、最轻量的版本探针。**
