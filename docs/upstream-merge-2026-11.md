# 上游合并问题清单（ISSUES.md）

同步上游 `clynamic/e1547`（基点 `c382cace`，2026-10-02）至 `a7e9c5db`（2026-11-24，v21.2.1+109）的合并问题清单。
按你的要求纳入版本管理：所有 bug 修复与业务变更在此显式标注。

## 一、bug 修复（借合并顺带修复的 fork 既有缺陷）

| # | 位置 | 问题 | 修复 |
| --- | --- | --- | --- |
| B1 | `lib/post/data/filter.dart` | fork 版 `_allowedPostsSet` 只在构造时建立且从不更新，`allow()` 后 `denies()` 依旧放行失败——"显示该帖"在当前会话无效 | 整体采用上游实现（`identical()` 短路 + 5 分钟 TTL 缓存），fork 的 4096 条目上限补丁废弃 |
| B2 | `lib/post/widget/search/slideshow.dart` | 幻灯片直接 `client.posts.page()` 取流，不经过 `PostFilter`，绕过客户端黑名单 | 见「业务变更」C2：幻灯片保留，黑名单注入沿用查询层 |
| B3 | `lib/post/widget/detail/widget/tag_export.dart` | 引用了上游已删除的 `getDefaultDownloadPath`，无法编译 | 改为 `settings?.downloadPath.value`；无设置时回退到下载器自身的目录选择流程 |
| B4 | `lib/settings/widget/settings.dart` | 引用了上游已删除的 `registerPin`，无法编译 | 改用上游新 PIN 组件 `choosePin`（`lib/app/widget/pin.dart`） |
| B5 | `lib/task/data/controller.dart` | fork 暂停窗口内 resume 会把任务卡在 running | 手工合并时补：resume 发现行仍是 running 则重新入队 |
| B6 | `lib/task/data/controller.dart` | `deleteDownloadedFile` 找不到上游新保存路径（`Pictures/<app>`） | 以 `basename(FileDownloader.displayPath(dir)) == 'Pictures'` 识别后追加应用文件夹层 |

## 二、业务变更（有意的行为差异，继承上游或 fork 决策）

| # | 位置 | 变更 | 说明 |
| --- | --- | --- | --- |
| C1 | e621 posts 接口 | 全部走 v2 响应结构（`files.*`/`stats.*`/`has.*`），显式 `v2=true&mode=extended` 兼容新旧节点 | 上游 `20c9f02b68` + `95e723bbde`；线上已默认 v2，fork 旧解析器已失效（2026-11-26 实测）。`docs/e621-api.md` §4 已回写 |
| C2 | 详情页 FAB | 保持删除状态（fork 产品决策）：操作收在信息行（复制标签/导出/下载/收藏）；上游重新引入的 FAB 代码在合并中移除 | 避免双爱心与编译失败 |
| C3 | `lib/user/data/batch.dart` 删除 | fork 的 `UserBatcher` 头像批量加载被上游原生方案替代（`UserSummaryAvatar` → `usePartial`/`QueryLoader`/`byIds`）；`UserClient.getMany` 一并删除 | 消除双系统重复请求（e621 限速 2rps）；`UserIdAvatar` 成为带默认跳转的薄包装 |
| C4 | 任务系统 | 下载并发数改为读设置 `downloadConcurrency`（fork 新增，1–8，默认 4）；取消模型用上游 `_canceledIds`；fork 的暂停/门控/速率显示保留 | `_updateCachedFavorite` 删除（保留会导致收藏数双加） |
| C5 | 收藏操作 | `addFavorite/removeFavorite` 迁移到上游 `useAddFavorite().mutate` 缓存变更流 | fork 的手写缓存回写不再需要 |
| C6 | 评论/回复操作 | `catchError`/`on ClientException` 迁移到上游 `(await mutate()).isError` 模式 | fork 的 catch 已死代码 |
| C7 | 黑名单过滤 | 客户端过滤逻辑整体采用上游（PostSummary 缓存 + TTL） | fork 的"空 denylist 跳过缓存"早退保留在上游版本等价行为中 |
| C8 | 锁屏 | `flutter_screen_lock` → 自研 PIN（`lib/app/widget/pin.dart`）+ 系统生物识别；后台 1 小时自动重锁 | 上游重写；PIN 设置走 `choosePin` |
| C9 | 弹层 | `sliding_sheet` → `smooth_sheets`（`showAppSheet`），手机端弹层可下滑关闭；桌面端对话框不变 | fork 独有对话框均为原生实现，不受影响 |
| C10 | 全屏查看 | `photo_view` → 上游自研 `Zoomable`；fork 的 InteractiveViewer 缩放补丁废弃 | fork 的逐帧控制仍在 `shared/video.dart` |
| C11 | 视频静音 | 上游 `muteVideos` 现在作用于全部池化播放器 | 已知边缘：网格自动播放预览音量为一次性设置，取消静音后预览可能出声（见「已知风险」） |
| C12 | CI | validation 工作流改为仅 `workflow_dispatch`；新增 `build_android_arm64_debug.yml`（手动触发，可选 ref） | 推送不再自动跑验证/构建 |

## 三、依赖与版本

- 移除 8 个依赖：`flutter_screen_lock`、`photo_view`、`sliding_sheet`、`external_path`、`html_character_entities`、`mutex`、`permission_handler`、`wakelock_plus`
- 新增：`smooth_sheets`、`skeletonizer`、`clock`、`local_auth_android`；dev 新增 `local_auth_platform_interface`、`file`
- **最低 Flutter 版本升至 3.47.4**（`get_flutter_version.sh` 读 pubspec 下界，CI 自动跟随）。本机 3.47.2 仅用于本地验证（临时下调下界，不入库），正式构建在 CI
- `pubspec.lock` 采用上游版本后由 `pub get` 重新生成
- 合并后版本号：21.2.1+109（继承上游）

## 四、i18n（zh-CN.json）

- 新增 31 条：锁屏/PIN 相关 11 条、搜索刷新状态 3 条、滑动关闭设置 3 条、用户资料统计/权限/状态 14 条
- 上游改写导致的 stale 键（94 条）：绝大多数是**动态键**（星期名走 `DateFormatting.named(...).tr`、枚举 `.name.tr`、翻译服务标签、主题色名等），静态扫描不可见，**保留不删**
- 其中探索页（已删除功能）遗留的死键为 fork master 上的既有欠账，不属于本次合并引入，本轮不动

## 五、已知风险 / 待办

| # | 风险 | 状态 |
| --- | --- | --- |
| R1 | **已确证为合并回归（CI 3.47.4 与本地 3.47.2 均复现）**：`test/post/widget/route_test.dart` 的 "a blacklisted post has a show button" 在点击 show 后触发框架语义树空值崩溃。崩溃链：`flushSemantics` → `_produceSemanticsNode/_buildSemanticsSubtree` 对某个 `geometry == null` 的脏节点取 `geometry!`（object.dart:6411/6271）。逐模块叠加二分（upstream + fork 各模块）确认崩溃来自 fork 代码的某种组合而非单文件；单文件还原（filter/likes/appbar/loading/image/tile/video/description/tag-card）均不能消除。场景特征：两条路由（画廊 PagedPageView + 被 push 的详情）共享同一 PostFilter，点击 show 触发跨路由通知重建时，覆盖路由下被缓存的语义子树进入脏队列但无几何。**仅测试绑定受影响**：生产语义树默认关闭，普通使用无影响；开启无障碍（TalkBack）时理论可触。 | 未修；已尝试 ExcludeSemantics 包裹（因包裹层不随 filter 通知重建而未生效）与 `addSemanticIndexes:false`（渲染对象来自更早帧缓存，仍崩溃）。后续方向：让画廊路由响应路由遮挡状态重建，或向上游报告框架语义遍历缺陷 |
| R2 | 网格 GIF/视频自动播放预览在取消静音后可能出声（C11） | 已知边缘，后续按需修复（预览监听服务通知重设音量） |
| R3 | 骨架占位数据（Ghost）的随机标签/描述可能被标签翻译当作真内容请求 | `TranslatedTagText` 有 `isSkeleton` 场景待加闸门，本轮未做 |
| R4 | fork 设置页新增项与上游新开关并存后，设置页长度显著增加 | 观感问题，后续轮按 UI 反馈调整 |

## 六、合并统计

- 冲突文件 62（60 内容 + 1 改/删 + pubspec.lock），冲突块 110，全部手工/代理解决后逐一复核标记清零
- 双方都改 117 文件：60 冲突、56 静默自动合并（已抽查语义）、1 无需合并
- fork 独有 116 文件全部存活；删除仅限 `lib/user/data/batch.dart`、`test/user/data/batch_test.dart`（被上游原生方案替代）与上游侧删除项
- 测试：671 项，670 过 1 失败（R1，本地与 CI 3.47.4 均复现）；`flutter analyze` 0 issue
