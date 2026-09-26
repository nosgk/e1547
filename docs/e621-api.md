# e621 API 参考（AI 必读）

> **适用范围**：任何涉及 e621 网络接口、搜索语法、响应解析的改动——新端点、新搜索参数、解析字段、错误处理。
>
> **核对流程**：先查本文（§4/§5 是逐项实测过的结论）→ 参数细节查 OpenAPI 规范 → 字段语义查帮助页存档 → 仍有疑问就按 §6 实测。
>
> **禁止凭训练记忆写参数**：同功能的端点路径会换代（`/counts/posts.json` vs 现行 `/posts/count.json`，差一个词就是 404）、参数名会记混。所有"应该是这样"都要落成 §6 的实测，实测结论回写本文并注明日期。

## 1. 三份资料

| 资料 | 位置 | 说明 |
| --- | --- | --- |
| OpenAPI 规范（参数级权威） | `docs/e621-openapi.yaml`（随 git 保存）＋ `Temp/openapi.yaml`（本地副本，可能更新） | 2026-09-26 取自 <https://e621.wiki/openapi.yaml>，约 450KB，含全部端点参数与响应 schema |
| 官方帮助页存档（语义/规则权威） | `e621-api文档.htm`（仓库根目录，**未纳入 git**） | <https://e621.net/help/api> 的保存页：UA 政策、认证、限速、状态码表、字段逐条说明 |
| 帮助页转文本脚本 | `tools/e621_doc_text.dart` | htm 是网页，rg 直接搜很吵；先转纯文本再查 |

### 1.1 检索 OpenAPI 规范

结构（行号对 2026-09-26 的仓库副本；重新下载后以 rg 定位为准）：

- L45–116 `components.parameters`：可复用查询参数（`search[id]`、`limit`、`page`、`order`…），端点内以 `$ref` 引用
- L117–5063 `components.schemas`：响应模型（Post / Tag / Pool / User / Wiki 的 JSON 字段）
- L5064 起全部路径；**index 端点也在**：`/posts.json` L9498、`/tags.json` L11158、`/pools.json` L9140、`/forum_topics.json` L7997、`/favorites.json` L7623

```bash
rg -n "operationId: posts#" docs/e621-openapi.yaml    # posts 相关操作一览
rg -n "search\[name_matches\]" docs/e621-openapi.yaml # 某参数在哪些端点可用
rg -n "post_count" docs/e621-openapi.yaml             # 响应字段在哪个 schema
```

### 1.2 检索帮助页存档

```bash
dart run tools/e621_doc_text.dart          # 生成 Temp/api_doc.txt
rg -n -i "post_count|name_matches" Temp/api_doc.txt
```

- htm 丢失时重新保存：浏览器打开 <https://e621.net/help/api> 另存为 `e621-api文档.htm`
- 更新仓库内规范副本：`curl -s https://e621.wiki/openapi.yaml -o docs/e621-openapi.yaml`（本机 shell 自带代理环境变量，直连即可）

## 2. 硬性规则（违反 = 被封或报错）

| 规则 | 细节 |
| --- | --- |
| User-Agent | 必须是描述性字符串 `项目名/版本 (by e621用户名)`；**伪装浏览器 UA 会被封**；无法设 header 时改用 `_client` 查询参数 |
| 限速 | 硬上限 2 rps（超限 503，偶尔 429）；持续请求 ≤1 rps。app 内由 `E621RetryInterceptor`（`lib/client/data/retry.dart`）兜底：GET 429/503 指数退避、遵循 Retry-After、上限 8s |
| 认证 | `Authorization: Basic base64(用户名:API密钥)`；无法设 header 时可用查询参数 `login`/`api_key`（仅调试用） |
| 分页 | 数字页码 >750 → **410 Gone**；大批量遍历用游标 `page=b<帖子id>`（首请求不带 page，之后取结果里最小 id）；**`page=a/b` 会强制 order:id_desc**（覆盖任何 `order:` metatag） |
| 请求体 | POST 用 urlencoded 或 multipart form-data |
| CORS | 仅 GET/POST 可跨域；PATCH/PUT/DELETE 不可（只影响网页端） |

## 3. 搜索语法（`/posts.json` 的 tags 参数，逐项实测）

### 3.1 运算符

- 组合就是空格分隔：`date:<2014-01-01 score:>=300`
- 否定 `-tag`；OR 用 `~` 前缀（`~type:webm ~type:gif` 实测仅返回 gif/webm）
- metatag 值可加双引号：`status:"deleted"`
- 括号分组：`( ~cat ~tiger ) ( ~dog ~wolf )`——**开括号后、闭括号前必须有空格**；嵌套 ≤10 层；`~`/`-` 可作用于整组

### 3.2 metatag 要点

- **没有类别前缀 metatag**：`species:`/`artist:` 这类写法不存在——按类别搜索就直接写 tag 本身（`dragon`）
- 每次搜索 ≤40 个 tag 且 **metatag 计入上限**；`status:` 每个分组限 1 个
- `date:`：`date:today` / `date:week` / `date:<…` / `date:>…` / `date:…`（当天）、范围 `2020-01..2020-06`
- `order:`：id / id_asc / id_desc / score / score_asc / favcount / favcount_asc / comment_count / random…（几乎都可用 `_asc` 或 `-` 反转）；**`order:random` 服务端整库洗牌极慢，禁止用于信息流**（app 的"随便看看"页因此被删）；要可复现配 `randseed:123`
- `fav:me` / `fav:用户名`：收藏夹隐藏的用户返回 `{"success":false,"reason":"Access Denied: …"}`（**不是 posts 数组**，解析必须能容）
- `id:1,2,3` 逗号列表按 id 查；`pool:<id>`；`type:jpg/png/gif/webm/...`
- `~` 与通配符组合的坑：`~african_*` 会把通配符展开成前 40 个匹配 tag 加入列表；`~*_cat` 按字面加入等于失效；否定通配符 `-african_*` 无数量限制

### 3.3 搜索总数

- **可用端点：`GET /posts/count.json?tags=<query>`**（OpenAPI `posts#count`，2026-09-26 副本 L9593）→ `{"count": N, "capped": bool}`
  - **封顶**：结果数超过约 24 万时固定返回 `240001 & capped:true`（实测全站、anthro 448 万、dragon 46.8 万均如此）；真实精确值只有单标签能从 `/tags.json` 的 `post_count` 拿到
  - 未超限时精确（实测 `dragon canine` → 55,719；`pool:1` → 24）
  - metatag 都接受：`pool:`、`id:`、`fav:`（隐藏收藏返回 0 而非报错）、`order:`（order 不筛选，等于未过滤总数）
- **老写法 `/counts/posts.json` 已 404**（Danbooru 风格旧路径；`/counts/posts`、e926 变体同样 404）。教训：差一个词就是另一个路由，以规范记载 + 实测为准
- app 显示规则（`_PostSearchCount`，搜索页标题旁）：单标签 → tags 索引精确值；其他非空搜索 → count.json，封顶渲染为 "{count}+"；空搜索与热页（order:rank）不显示

## 4. 端点形状速查（app 用到的）

| 端点 | 要点 |
| --- | --- |
| `GET /posts.json` | 顶层数组（`unwrapRailsArray` 拆包）；limit ≤320；已删除帖要 `status:deleted`/`status:any` 才返回 |
| `GET /posts/{id}.json` | 返回 `{post: {...}}` |
| `GET /favorites.json` | **必须带认证，否则 404**；返回 `{posts: [...]}` |
| `POST /posts/{id}/votes.json` | `score=1|-1&no_unvote=true` |
| `GET /tags.json` | `search[name_matches]` 支持 `*` 通配；`search[category]` 用**站点数值**（见下表）；`search[hide_empty]` 默认 true——0 帖的 tag 查不到；`search[order]=count` 拉高频标签；limit ≤320 |
| `GET /tag_aliases.json` | `search[antecedent_name]` 等 |
| `GET /pools.json`、`/pools/{id}.json` | pool 响应带 `post_ids`（有序）与 `post_count` |
| `GET /users.json` | 索引响应**缺** favorite_count / forum_post_count / comment_count / profile 字段（只有 `/users/{id}.json` 才有）→ 解析必须容空，否则头像批量解析全体失败；`search[id]=1,2,3` 逗号分隔 ≤320；`search[name_matches]` 精确匹配 |
| `GET /forum_topics.json` | `search[order]` 只有 `id_asc|id_desc|sticky`；**省略 = 最新回复序**（updated_at 降序）——别发明 last_reply 排序 |
| `GET /wiki_pages.json` | `search[title]` |
| `GET /status.json` | 站点可用性探测 |

站点 tag category 数值（`search[category]` 传参与响应 `category` 字段）：**0 general、1 artist、2 contributor、3 copyright、4 character、5 species、6 invalid、7 meta、8 lore**。
app 内 `TagCategory` 枚举顺序与之**不一致**（general, species, character, copyright, meta, lore, artist, contributor, invalid）——传参用上表站点值，**不要用 `TagCategory.index`**。

## 5. 实测命令模板

```bash
# 本机 shell 自带代理环境变量，直连即可；UA 按规范写
curl -s -A "e1547-dev/1.0 (by 你的e621用户名)" "https://e621.net/posts.json?tags=dragon&limit=1"
curl -s -A "e1547-dev/1.0 (by 你的e621用户名)" "https://e621.net/tags.json?search[name_matches]=dragon"
# 私有数据（收藏等）加 Basic 认证
curl -s -u "用户名:api_key" -A "e1547-dev/1.0 (by 你的e621用户名)" "https://e621.net/favorites.json"
```

判读：**404 ＋ e621 风格 HTML 页 = 路由不存在**（端点已下线）；403 ＋ 挑战页 = Cloudflare 拦截（换 UA 或走 app 的 Resolve 流程）；429/503 = 限速，退避重试。

## 6. 本项目对接约定

- 分层：`lib/<域>/data/client.dart` = 裸 dio 请求；`lib/<域>/data/query.dart` = 缓存查询扩展（`Query`/`InfiniteQuery`/`Mutation` + `dio.queryCache`，key 用 `dio.identityQueryKey(domain)`）
- 解析：`unwrapRailsArray` 统一拆包；`E621*.fromJson` 一律容空（模型字段可空，解析不得比模型严——头像全体加载失败的回归就是 `asIntOrThrow` 引起的）
- `QueryMap` 的值必须全是**字符串**（如 `'limit': '320'`）
- 测试：`FakeE621`（`test/_support/fake_e621.dart`）＋ `test/_fixtures/*.json`；新端点先在 FakeE621 加路由（`search[name_matches]` 的假实现 = 精确匹配）；用到缓存 Query 的测试必须 `dio.queryCache = CachedQuery.asNewInstance()` ＋ `dio.queryIdentity = 1`（`dioFor` 不设置）
- CI 三道门禁：`dart format` → `flutter analyze` → `flutter test`；本机跑测试先清空 `http_proxy`/`https_proxy`/`all_proxy`（代理会拦截 flutter_tester 的本地 WebSocket）

## 7. 维护

- 实测发现与本文冲突的事实：在改代码的同一个提交里回写 §3/§4，并注明日期
- 更新 `docs/e621-openapi.yaml` 后，用 §1.1 的 rg 命令重新定位结构行号并同步本文
