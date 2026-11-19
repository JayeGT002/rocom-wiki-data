# BWiki (wiki.biligame.com) 数据抓取指南

> 面向 agent 的抓取参考，适用于 `wiki.biligame.com` 下任意子站（本仓库用 `/nrc/`）。
> 最近实测：2026-11-14。

## 1. 端点与 WAF 行为

| 端点 | 状态 | 说明 |
|---|---|---|
| `api.php`（MediaWiki Action API） | 间歇可用 | 2026-11-05 全量同步成功；2026-11-14 探测成功，随后批量请求触发 567 |
| `index.php?title=XXX&action=raw` | 间歇可用 | 通常比 API 宽松，但 2026-11-14 同样被 567 拦截 |
| 普通页面 / `Special:PrefixIndex` | 不稳定 | 不作为数据来源 |

**结论：不要假设端点固定可用。** 567 更像 IP/频率策略，触发后需要冷却；单次探测和批量抓取的可用性可能不同。

**拦截页特征**：
- HTTP 567
- 响应体约 7351–7352 字节
- 开头 `<!doctype html><html lang=zh-CN>`
- 响应头含 `Server: TencentEdgeOne`、`EO-LOG-UUID`

请求头只需常规浏览器 UA：

```
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36
Accept-Language: zh-CN,zh;q=0.9
```

不需要 Cookie / Referer。

## 2. 抓取方式

### 2.1 API 批量取内容

```text
GET https://wiki.biligame.com/nrc/api.php
  ?action=query
  &prop=revisions
  &rvprop=ids|timestamp|size|content
  &rvslots=main
  &titles=模块:Pets/data/Config|模块:Pets/data/Catalog
  &format=json&formatversion=2
```

- 一次 5–10 个标题；大文件（`Catalog.lua` ~950KB）留 90s 超时。
- 内容在 `query.pages[i].revisions[0].slots.main.content`。
- 页面不存在返回 `missing: true`。

### 2.2 raw 兜底

```text
GET https://wiki.biligame.com/nrc/index.php?title={URL编码标题}&action=raw
```

单个模块、体积小时优先用 raw；被 567 时按第 3 节退避。

## 3. 频率与 567 处理

- 纯顺序请求，间隔 1.5s 以上；**禁止并发**。
- 被 567 后不要立刻重试：至少冷却 30s，再 2/4/8 分钟退避。
- 连续 567 时，停止批量抓取，改用已有本地模块 + 版本探针判断是否值得重试。
- 单次探测（1–2 个请求）通常比批量更容易通过；先用探针拿版本号，再决定是否全量。

## 4. 模块清单

### 4.1 `Module:Pets/*`（18 个页面）

```text
模块:Pets
模块:Pets/EvolutionConditions
模块:Pets/SeasonConfig
模块:Pets/SeasonData
模块:Pets/Theme
模块:Pets/data/Catalog          # 核心：编号 1–468，633 条
模块:Pets/data/Config           # 版本 / 赛季 / pet_count
模块:Pets/data/Evolutions
模块:Pets/data/Handbooks
模块:Pets/data/History
模块:Pets/data/Index
模块:Pets/data/Learnsets
模块:Pets/data/Overview
模块:Pets/data/SkillStoneTopics
模块:Pets/data/Skills
模块:Pets/data/Terms
模块:Pets/data/TrainingReference
模块:Pets/data/Types
```

### 4.2 S5 赛季压缩模块（6 个页面）

```text
模块:精灵图鉴/S5/配置            # namespace / modules / object_tag / array_tag
模块:精灵图鉴/S5/数据/精灵       # Roster：245、254、469–496，共 32 条
模块:精灵图鉴/S5/数据/辅助       # Overview/Evolutions/Handbooks/Index/Types 补丁
模块:精灵图鉴/S5/数据/技能
模块:精灵图鉴/S5/数据/特性
模块:精灵图鉴/S5/数据/关联
```

S5 起 `Catalog` 不再收录新精灵。Roster 采用 `dragon-tuples-1`：

```lua
return { "dragon-tuples-1", { "字段名1", "字段名2", ... },
  { 对象标记, { {字段下标, 值}, ... } } }
```

- 对象节点 `{1, {{idx, value}, ...}}`（`object_tag`，默认 1）
- 数组节点 `{2, {v1, v2, ...}}`（`array_tag`，默认 2）
- 下标对应第 2 项字段名表

## 5. 本仓库同步工具

```bash
# 模块比对 / 更新（写入 data/wiki_modules/）
python3 tools/sync_wiki.py
python3 tools/sync_wiki.py --apply

# S5 解码 + 赛季文件维护
python3 tools/s5_sync.py --season
python3 tools/s5_sync.py --s4
```

- `sync_wiki.py` 覆盖 24 个模块（18 个 Pets + 6 个 S5）。
- `s5_sync.py` 从 `data/wiki_modules/精灵图鉴/S5/` 解码，写入 `data/seasons/S5Season.lua`，并保留手工 `starlight` / `review_gold`。

## 6. 新模块发现

`list=allpages&apnamespace=828` 在 API 可用时可枚举 Module 命名空间；API 被拦时无法可靠发现新页面。维护策略：

- 版本探针：`Module:Pets/data/Config` + `模块:精灵图鉴/S5/配置`
- 已知清单外的新模块，人工确认后再加入 `tools/sync_wiki.py` 的 `MODULE_TITLES`
