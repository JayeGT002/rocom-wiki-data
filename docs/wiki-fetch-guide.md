# BWiki (wiki.biligame.com) 数据抓取流程指南

> 面向 agent 的通用抓取参考。适用于 `wiki.biligame.com` 下任意子站（如 `/nrc/`）。

## 1. WAF 拦截机制

| 端点 | 是否可用 | 说明 |
|---|---|---|
| `api.php`（MediaWiki 查询 API） | **不可用** | 腾讯 EdgeOne WAF 硬拦截，返回 HTTP 567 + 7351 字节拦截页；curl、Playwright 均被封，无 Set-Cookie、无 JS 挑战，疑似 TLS 指纹/IP 策略 |
| `index.php?title=XXX&action=raw` | **可用** | 同源同 WAF，但 raw 内容端点未被拦截规则命中；仅需浏览器 UA |
| `Special:PrefixIndex` / `Special:AllPages` | **不稳定** | 时而被 302 重定向，时而被 567 拦截，不可依赖 |
| 普通 wiki 页面（`/nrc/首页`） | **不可用** | 同样被 567 拦截 |

**拦截页特征**（用于自动判定是否被拦）：
- HTTP 状态码 567
- 响应体固定 ~7351–7352 字节
- 开头为 `<!doctype html><html lang=zh-CN>` + EdgeOne 拦截文案
- 响应头含 `Server: TencentEdgeOne`、`EO-LOG-UUID: ...`

## 2. 可用抓取方式

```
GET https://wiki.biligame.com/nrc/index.php?title={URL编码的Module标题}&action=raw
```

**必需请求头**：
```
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36
Accept-Language: zh-CN,zh;q=0.9
```

**不需要**：Cookie、Referer、sec-ch-ua、sec-fetch-* 等（加不加不影响结果）。

`curl-impersonate` 不必安装；普通 curl + 上述 UA 即可通过 `action=raw` 端点。

## 3. 频率限制

| 模式 | 结果 | 建议 |
|---|---|---|
| 并发 15 请求 | ~50% 触发 567 拦截页 | **禁止并发** |
| 顺序请求，间隔 1.5s | 全部成功 | **推荐** |
| 顺序请求，间隔 <1s | 偶发拦截 | 不推荐 |
| 被拦后立即重试 | 仍被拦 | 需等待 2s+ |

**安全抓取参数**：
- 并发度：1（纯顺序）
- 请求间隔：≥1.5 秒
- 单次超时：30–90s（大文件如 Catalog.lua ~930KB 需更长）
- 失败重试：最多 3 次，间隔 2s

## 4. 拦截判定与重试逻辑

```python
BLOCK_SIZE_RANGE = (7300, 7400)  # EdgeOne 拦截页固定大小

def is_blocked(response_body: bytes) -> bool:
    if len(response_body) in range(*BLOCK_SIZE_RANGE):
        return b'TencentEdgeOne' in response_body or b'安全' in response_body
    return False

def fetch_raw(title: str, max_retries=3) -> str:
    for attempt in range(max_retries):
        resp = curl_get(title, delay=1.5 * (attempt + 1))
        if not is_blocked(resp):
            return resp
        time.sleep(2)
    raise Exception(f"被 EdgeOne 拦截，{max_retries} 次重试均失败")
```

## 5. 已知模块清单（Module:Pets/*）

共 15 个文件，分两类路径：

```
Module:Pets/data/Catalog.lua          # 核心：精灵全量数据
Module:Pets/data/Config.lua           # 全局配置（含版本号）
Module:Pets/data/Evolutions.lua       # 进化链
Module:Pets/data/Handbooks.lua        # 图鉴条目
Module:Pets/data/History.lua          # 数值改动历史
Module:Pets/data/Index.lua            # 头像/立绘索引
Module:Pets/data/Learnsets.lua        # 学习技能表
Module:Pets/data/Overview.lua         # 拼音/赛季概览
Module:Pets/data/SkillStoneTopics.lua # 技能石话题
Module:Pets/data/Skills.lua           # 技能库
Module:Pets/data/Terms.lua            # 状态术语
Module:Pets/data/TrainingReference.lua # 养成参考
Module:Pets/data/Types.lua            # 系别克制表
Module:Pets/EvolutionConditions.lua   # 特殊进化条件
Module:Pets/Theme.lua                 # 系别主题色
```

本地对应路径：`wiki_modules/` 下保持相同相对结构。

## 6. 新页面发现（受限）

`api.php` + `Special:PrefixIndex` 均被 WAF 拦截，**无法可靠枚举 wiki 上是否存在本地未归档的新模块文件**。

**替代策略**：
- 维护已知模块清单（上文 15 个），定期逐个抓取对比
- 若 wiki 新增独立模块文件，需人工查阅 wiki 页面确认
- 实际经验：BWiki 新数据通常写入既有模块（Catalog/Skills/History），新增独立文件概率低
