# 洛克王国世界图鉴数据仓库（Rocom Wiki Data）

本项目聚合了《洛克王国世界》（Rocom）的图鉴 Excel 表格与从 **洛克王国世界 WIKI** 提取的原始数据模块，供需要图鉴/数值数据的开发者与玩家查阅、二次开发使用。

> 数据仅作整理与归档，**一切数值以 [洛克王国世界 WIKI](https://wiki.biligame.com/nrc) 实时页面为准**，本项目不保证与游戏内最新版本完全同步。

## 仓库内容

| 文件 / 目录 | 说明 |
|---|---|
| `洛克王国世界图鉴Lite.xlsx` | 整理好的图鉴电子表格（图鉴编号、家族、属性、蛋组、雌雄比例、身高体重、星光/洛克贝、精灵蛋范围、赛季与分类等） |
| `wiki_modules/` | 从 WIKI 的 `Module:Pets/*` 抓取的全部数据模块（Lua 格式，仅供数据参考） |
| `S4Season.lua` | S4 月涌狂想赛季新增精灵的独立数据文件（图鉴 443–465） |

## S4 赛季独立数据文件

为确保抓取数据的原样性，S4 赛季新增精灵全部独立到新增文件 `S4Season.lua` 中，可按需替换/读取，后续新赛季均按此规律新增文件。

- 范围：图鉴 **443–465**（狼灵 443–445 与鹭、米龙、章脑、玳龟、量风碗、小浣蛋、幽铃、星星眼、布灵等 S4 新精灵家族，共 23 个编号），与 `洛克王国世界图鉴Lite.xlsx` 中「所属赛季 = S4月涌狂想」的行一一对应。
- 结构：抽取自 `wiki_modules/Pets/data/Catalog.lua` 的原始 Lua 块，并按 Catalog 内既有写法补注 `starlight`（星光值）与 `review_gold`（洛克贝，= 星光值×50）字段。
- 版权：数据来自洛克王国世界 WIKI + 手工补全，遵循 **CC BY-NC-SA 4.0**。

## wiki_modules 目录各文件用途

按 `Module:Pets/` 下的实际路径罗列（均为 Lua 数据文件，结构为 Lua table）：

| 文件路径 | 用途 |
|---|---|
| `Pets/data/Catalog.lua` | ★ 核心：精灵全量图鉴数据。含精灵编号/名称、系别、种族值六维（atk/def/hp/spa/spd/spe）、蛋组、**蛋重范围(egg_size)**、性别比例、身高/体重、星光值、洛克贝（基础 reward）、克制亲和(affinity)、捕捉阈值、是否可骑行、进化ID、图鉴ID 等 |
| `Pets/data/Config.lua` | 全局配置：血统(bloodline)列表、构建形态等基础参数 |
| `Pets/data/Evolutions.lua` | 进化链数据：各精灵的进化阶段、形态、进化到/进化自关系 |
| `Pets/data/Handbooks.lua` | 图鉴条目数据：栖息地、图鉴标题、话题(topics)、进度、奖励等 |
| `Pets/data/History.lua` | 数值改动历史：技能/精灵的 before/after 平衡性调整记录 |
| `Pets/data/Index.lua` | 索引映射：精灵 ID → 头像/立绘图片文件名 |
| `Pets/data/Learnsets.lua` | 学习技能表：各血统、各等级可习得的技能 |
| `Pets/data/Overview.lua` | 快捷概览：精灵拼音搜索词、所属赛季(season) |
| `Pets/data/SkillStoneTopics.lua` | 技能石话题：技能石绑定的图鉴话题、精灵、图标 |
| `Pets/data/Skills.lua` | 技能库：技能名称、类别(特性/技能)、系别、耗能、描述 |
| `Pets/data/Terms.lua` | 状态术语：中毒、灼烧等异常/状态效果说明 |
| `Pets/data/TrainingReference.lua` | 养成参考：血统、标签、训练参考资料及图标路径映射 |
| `Pets/data/Types.lua` | 系别克制表：单系与双系的克制/抵抗/弱点倍率(resist/weak) |
| `Pets/EvolutionConditions.lua` | 精灵特殊进化条件（Wiki 侧可直接编辑的映射数据） |
| `Pets/Theme.lua` | 系别主题色映射（PetDex 图鉴流配色编号） |

## 版权归属与开源协议

- **数据资源来自** [洛克王国世界WIKI](https://wiki.biligame.com/nrc)（内容上传/维护者为 WIKI 贡献者）。
- 本项目遵循上游共享协议 **CC BY-NC-SA 4.0（署名-非商业性使用-相同方式共享）**。
- 说明：
  - **署名（BY）**：使用或转载时须注明来源「洛克王国世界 WIKI」，并提供指向本声明与上游页面的链接。
  - **非商业性使用（NC）**：不得将本项目内容用于商业目的。
  - **相同方式共享（SA）**：基于本项目内容的演绎作品，须以相同许可协议(CC BY-NC-SA 4.0)发布。
- 完整许可条文见 [LICENSE](./LICENSE) 与本协议[官方法律文本](https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode.zh-Hans)。
- 引用数据模块 `wiki_modules/` 为 WIKI Lua 数据的镜像归档，版权归 WIKI 及原作者所有，本项目仅作整理与索引。

## 其他

- 更新时间：基于北京时间 2026-09-10 14:43:58（UTC+8，对应 Wikidata WIKI 数据开始抓取时刻）抓取的 WIKI 数据。
- 最近一次数据更新：北京时间 2026-09-10 16:45:45（UTC+8）——优化表格排版（调整「属性（合并）」等列顺序），并修正部分精灵数据。
- 更新规范：此后每次数据更新，均须在 README「其他 → 更新时间」记录**完整详细时间**（北京时间，精确到秒并标注 UTC+8），不得以月/年级别的模糊时间代替。
- 如需同步最新数据，请访问 [洛克王国世界 WIKI - 精灵图鉴](https://wiki.biligame.com/nrc/精灵图鉴)。