# 版本差异检测方法

> 轻量探针：先判断是否需要全量同步，再抓模块。
> 最近核验：2026-11-14。

## 1. 两条数据线

| 数据线 | 探针 | 当前值（2026-11-14） |
|---|---|---|
| 旧版 Catalog | `data/wiki_modules/Pets/data/Config.lua` 的 `current_version` / `pet_count` | `s5-2026-10-31` / 633 |
| S5 赛季 | `data/wiki_modules/精灵图鉴/S5/配置.lua` 的 `current.last_number` / `name` | 496 / 圣龙宝藏 |

- `Config.lua` 只覆盖编号 1–468 的旧线，**不含** S5 新精灵。
- S5 实际内容看 `模块:精灵图鉴/S5/数据/精灵` 的 `revid`；494–496 目前是 `CatalogPlaceholders`（只有编号、无名称）。

## 2. 检测流程

```text
Step 1  抓 2 个探针：Config.lua + S5/配置.lua（2 个请求）
Step 2  比对 current_version / pet_count / last_number / name
Step 3  有变化 → tools/sync_wiki.py --apply 全量比对
Step 4  S5 数量或 revid 变化 → tools/s5_sync.py --season
Step 5  用 tools/query_pet.py 与 tools/build_site_data.py 验证
```

## 3. 示例

```bash
python3 tools/query_pet.py 481 --season S5
python3 tools/build_site_data.py
python3 tools/sync_wiki.py          # dry-run，先看差异
```

`tools/sync_wiki.py` 的 dry-run 会输出 `SAME / DIFF / NEW / MISS`，并列出远端 revid 与时间戳；确认后再加 `--apply`。

## 4. 注意

- API 可能返回 567，探针失败不代表数据没更新；冷却后重试，或参考 `docs/wiki-fetch-guide.md`。
- 2026-11-05 与 2026-11-14 两次核验：版本仍为 `s5-2026-10-31`、`pet_count=633`、S5 `last_number=496`，没有新增 S5 精灵；但 `Catalog` / `Evolutions`（2026-11-06，贝瑟家族 `evolution_id` 改名）与 `EvolutionConditions`（2026-11-08）有修订，已于 2026-11-14 同步。
- 全量抓取代价约 4.5MB / 24 个模块；只在探针变化或需要复核时执行。
