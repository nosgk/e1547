<table>
  <tr>
    <td width="20%">
      <img src="assets/icon/app/round.png"/>
    </td>
    <td width="80%">
      <h1>e1547（中文分支）</h1>
      <h4>一款精致的 e621 浏览器 · 上游 fork 的中文化增强版</h4>
      <a href="https://github.com/nosgk/e1547/commits/master"><img src="https://img.shields.io/github/commit-activity/m/nosgk/e1547"></a>
      <a href="https://github.com/nosgk/e1547/commits/master"><img src="https://img.shields.io/github/last-commit/nosgk/e1547"></a>
      <a href="blob/master/LICENSE"><img src="https://img.shields.io/github/license/nosgk/e1547"></a>
      <img src="https://img.shields.io/badge/上游-clynamic%2Fe1547-blue">
      <img src="https://img.shields.io/badge/当前版本-21.2.1%2B109-green">
    </td>
  </tr>
</table>

本仓库是 [clynamic/e1547](https://github.com/clynamic/e1547) 的下游 fork：在完整同步上游全部功能的基础上，做了**全面中文化**与一系列自有功能增强。上游的核心功能（浏览帖子与合集、编辑、评论、下载、收藏与投票、标签关注推送、本地黑名单、DText 解析、视频播放、多账号、多主题等）全部保留。

## 本分支的额外功能

### 🌐 全界面中文

- 全部界面文案的中文翻译（zh-CN，800+ 条目，随每次改动同步维护）
- 标签名在线翻译：详情页/合集页可开关的标签翻译，逐标签请求并去重，支持批量限流、错误重试与翻译缓存
- 页面正文翻译：帖子描述、用户简介、评论与回复可一键翻译（支持 OpenAI 兼容接口、Google、Azure 等多种翻译源，可自定义请求模板）
- 智能跳过：文本本身是中文时不重复翻译；骨架屏占位内容不发起请求

### 🔗 搜索链接双向同步

- **分享搜索**：搜索页一键把当前搜索复制/分享为规范的 `e621.net/posts?tags=…` 网页链接
- **打开链接即达**：从浏览器或他人分享打开 e621/e926 搜索链接，应用直接落在对应信息流（兼容 `tags=` 与 `search[tags]=` 两种拼写，自动纠正非法参数）

### 📊 搜索命中总数

- 搜索页标题旁实时显示命中数量：单标签取标签索引的精确值，其余搜索走计数接口（超过约 24 万显示为「N+」）
- 计数使用固定槽位占位，加载过程不推动工具栏布局

### ⚡ 加载引擎对齐 e621 最新 API

- posts 接口适配 v2 响应结构（`files.*`/`stats.*`/`has.*`），`v2=true&mode=extended` 兼容新旧节点
- 全部 `order:`/`status:`/`type:`/`rating:` 参数逐项实测核对（15 + 6 + 6 + 3 个合法值）
- 客户端参数护栏：页大小自动 clamp 至 320，数字页码超 750 本地即报错并提示游标分页
- 完整的中文 API 参考文档见 [docs/e621-api.md](docs/e621-api.md)（含实测事实表与 curl 模板）

### 🧰 任务与下载增强

- 下载并发数可调（1–8）
- 下载进度、速率显示与暂停/恢复
- 清理已完成任务时可同时删除本地文件（兼容 SAF 与新 `Pictures/<应用名>` 路径）

### 🎨 界面细节

- 抽屉、设置页大量中文语境排版调整
- 快捷搜索预设（主页抽屉可增删改查，长按标签快速存为预设）
- 万能摇奖机、禅模式幻灯片等搜索小工具
- 深色主题下的翻译文案可读性优化

## 下载

| 文件 | 适用 |
| --- | --- |
| `e1547-arm64-v8a-release.apk` | 2019 年及之后的多数手机（arm64） |
| `e1547-armv7-release.apk` | 旧设备（armv7） |
| `e1547-universal-release.apk` | 不确定设备型号时的兜底 |

前往 [Releases](https://github.com/nosgk/e1547/releases/latest) 下载。

> ⚠️ 本分支与上游签名不同：安装过上游版本（Play 商店 / F-Droid / clynamic 发布版）的设备需先卸载后再安装。

推荐使用 [Obtainium](https://github.com/ImranR98/Obtainium) 管理更新：添加应用源 `https://github.com/nosgk/e1547/releases/` 即可跟随本分支发版。

## 与上游的同步策略

- 上游跟踪远程为 `clynamic/e1547`，同步方式为合并提交（历史可完整追溯）
- 每轮同步的问题清单与取舍记录在 [docs/upstream-merge-2026-11.md](docs/upstream-merge-2026-11.md)
- 涉及 e621 接口的改动一律先核对 [docs/e621-api.md](docs/e621-api.md) 的实测事实表

## 自行编译

1. 安装 [Flutter](https://flutter.dev/docs/get-started/install)（≥ 3.47.4）
2. 克隆本仓库
3. `flutter build apk --release`（或 `--target-platform android-arm64` 只出 arm64）

CI 三道门禁：`dart format` → `flutter analyze` → `flutter test`；Android 构建走 GitHub Actions（`deployment.yml` 手动触发，`build_debug=true` 可出调试包）。

## 致谢

本项目基于 [clragon](https://github.com/clragon) 的 [clynamic/e1547](https://github.com/clynamic/e1547)——一个充满热情的项目。感谢上游作者与所有贡献者（[Perlatus](https://github.com/perlatus) 的原始代码、[aza0](https://github.com/purrfecto114-lgtm) 的密集除错、[Miyoyo](https://github.com/miyoyo) 的性能优化）。

License: [GPL-3.0](LICENSE)（继承上游）
