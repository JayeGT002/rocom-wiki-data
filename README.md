# 洛克王国世界图鉴数据仓库（Rocom Wiki Data）

本仓库归档《洛克王国世界》（Rocom）的 WIKI Lua 模块、独立赛季数据和整理后的图鉴表格，供玩家查阅及开发者二次使用。

> 数据仅作整理与归档，一切数值以[洛克王国世界 WIKI](https://wiki.biligame.com/nrc)实时页面为准。本项目不保证与游戏内最新版本完全同步。

## 目录结构

```text
.
├── data/
│   ├── wiki_modules/Pets/       # WIKI Module:Pets 的原始 Lua 数据镜像
│   ├── seasons/S4Season.lua     # 按赛季独立维护的 Lua 数据，可继续添加 S5、S6…
│   └── spreadsheets/            # 整理后的图鉴工作簿
├── tools/
│   ├── pet_data.py              # Lua 来源适配、解析和统一数据模型
│   ├── query_pet.py             # 本地查询命令
│   └── build_site_data.py       # 生成网页使用的 JSON 数据
├── site/                        # GitHub Pages 静态查询表格
├── .github/workflows/pages.yml  # 自动构建和部署
├── LICENSE
└── README.md
```

归档数据集中在 `data/`，按来源和用途分类；`tools/` 放数据读取与构建工具。各 Lua 文件保留原始 table 结构，不会被工具改写。

## 查询方式

### 命令行

需要 Python 3，无第三方依赖。在仓库根目录执行：

```bash
python3 tools/query_pet.py 001
python3 tools/query_pet.py 星星眼
python3 tools/query_pet.py 463 --source seasons --season S4
python3 tools/query_pet.py 443 --all
```

默认查询全部来源。`--source catalog` 只查 WIKI Catalog，`--source seasons` 查所有独立赛季文件；`--season S5` 可限制到单个赛季。查询适配器自动发现 `data/seasons/S数字Season.lua`，因此添加 `S5Season.lua`、`S6Season.lua` 后无需修改脚本中的赛季列表。多来源记录按 `pet_id` 路由到统一视图，赛季文件中的非空字段优先，原始 Lua 文件仍独立保存。

数字参数按图鉴编号查询；名称支持部分匹配；`pet_` 参数按精灵 ID 查询。多个形态可用 `--all` 显示。

### GitHub Pages 表格

网页提供关键词搜索、赛季/来源/属性筛选、字段与比较方式可选的多条件 AND/OR 构造器、可选显示列、表头排序、分页、CSV 导出和可分享的查询链接。浏览器只读取静态 JSON，不需要后端服务或第三方运行时依赖。

本地预览：

```bash
python3 tools/build_site_data.py
python3 -m http.server 8000 --directory site
```

新增赛季 Lua 文件后，Pages 工作流会重新生成 JSON 并部署网站。启用时，在仓库 **Settings → Pages → Build and deployment** 中将发布来源选为 **GitHub Actions**；之后合入 `main` 会自动部署。手工触发可在 Actions 页面运行 `Build and deploy data browser`。

## 数据来源

### WIKI Lua 模块

`data/wiki_modules/Pets/` 镜像 WIKI 的 `Module:Pets/*` 数据。主要文件如下：

| 文件 | 内容 |
|---|---|
| `data/wiki_modules/Pets/data/Catalog.lua` | 精灵编号、名称、属性、种族值、蛋组、蛋重、性别比例、身高体重、星光值、洛克贝等图鉴资料 |
| `data/wiki_modules/Pets/data/Config.lua` | 血统列表及构建形态等全局配置 |
| `data/wiki_modules/Pets/data/Evolutions.lua` | 进化阶段与关系 |
| `data/wiki_modules/Pets/data/Handbooks.lua` | 栖息地、图鉴标题、话题、进度与奖励 |
| `data/wiki_modules/Pets/data/History.lua` | 技能及精灵数值调整历史 |
| `data/wiki_modules/Pets/data/Index.lua` | 精灵 ID 到图片文件名的映射 |
| `data/wiki_modules/Pets/data/Learnsets.lua` | 各血统和等级可习得的技能 |
| `data/wiki_modules/Pets/data/Overview.lua` | 搜索词与赛季信息 |
| `data/wiki_modules/Pets/data/SkillStoneTopics.lua` | 技能石话题、绑定精灵与图标 |
| `data/wiki_modules/Pets/data/Skills.lua` | 技能与特性资料 |
| `data/wiki_modules/Pets/data/Terms.lua` | 状态效果术语 |
| `data/wiki_modules/Pets/data/TrainingReference.lua` | 养成参考资料与图标映射 |
| `data/wiki_modules/Pets/data/Types.lua` | 系别克制关系与倍率 |
| `data/wiki_modules/Pets/EvolutionConditions.lua` | 特殊进化条件 |
| `data/wiki_modules/Pets/Theme.lua` | 系别主题色 |

### 独立赛季数据

`data/seasons/` 按赛季存放独立数据，目前 `S4Season.lua` 保存 S4 月涌狂想赛季资料，范围为图鉴 **443–465**，共 23 条记录。后续赛季各自新增 `S5Season.lua`、`S6Season.lua` 等文件，不必改写 WIKI 原始模块，也不需要改动查询器或网页代码。

S4 文件从 WIKI Catalog 原始记录整理，并按项目约定补充 `starlight`（星光值）和 `review_gold`（洛克贝，星光值×50）。WIKI 原始数据与手工维护字段的来源不同，更新时应分别核对、分别保留。

### 图鉴工作簿

`data/spreadsheets/洛克王国世界图鉴Lite.xlsx` 汇总图鉴编号、家族、属性、蛋组、雌雄比例、身高体重、星光值、洛克贝、精灵蛋范围、赛季和分类等字段。

## 版权与许可

- 数据资源来自[洛克王国世界 WIKI](https://wiki.biligame.com/nrc)，内容上传和维护者为 WIKI 贡献者。
- WIKI 数据及其衍生内容遵循 **CC BY-NC-SA 4.0**：使用时注明来源、不得用于商业目的，演绎作品须使用相同协议。
- Lua 模块是 WIKI 数据的镜像归档，版权归 WIKI 及原作者所有；本项目遵循上游共享条件。
- 完整许可见 [LICENSE](./LICENSE) 和[协议法律文本](https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode.zh-Hans)。

## 更新时间

- WIKI 数据抓取开始时间：北京时间 2026-09-10 14:43:58（UTC+8）。
- 最近一次工作簿整理：北京时间 2026-09-10 16:45:45（UTC+8），调整表格列顺序并修正部分精灵资料。
- 每次更新数据时，在此记录完整的北京时间时间戳，精确到秒并标注 UTC+8。
- 最新资料请查阅[洛克王国世界 WIKI 精灵图鉴](https://wiki.biligame.com/nrc/精灵图鉴)。
