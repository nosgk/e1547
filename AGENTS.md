# AGENTS.md

## e621 API（改网络相关代码前必读）

任何涉及 e621 接口、搜索语法、响应解析的改动，先读 **[docs/e621-api.md](docs/e621-api.md)**：两份权威资料（`docs/e621-openapi.yaml`、根目录 `e621-api文档.htm`）＋ 逐项实测的事实表 ＋ curl 验证模板。禁止凭记忆写参数——同功能端点路径会变（例：总数端点老路径 `/counts/posts.json` 已 404，现行 `/posts/count.json`），差一个词就是另一个路由。

## 每次改动的固定收尾

- 新 UI 文案同步补 `assets/i18n/zh-CN.json`（单行条目：en/zh/ctx，占位符 `{name}`，保持既有键的排序与缩进风格）
- 三道门禁全绿再提交：`dart format <改动文件>` → `flutter analyze` → 清空代理后 `flutter test`（`http_proxy`/`https_proxy`/`all_proxy` 置空，否则 flutter_tester 的本地 WebSocket 连不上）
