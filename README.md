# DiskCleanerApp

macOS 原生磁盘分析与小范围清理工具（Swift + SwiftUI）。功能包括：按可配置阈值列出大文件、低于阈值的小文件按父目录与「应用/标识」聚合（甜甜圈图 + 可筛选的目录明细）、内置开发缓存 JSON 清单（可清理 / 谨慎 / 禁止）。

**系统要求**：macOS 14 及以上（SwiftUI Charts 等 API）。

## 应用图标

- **图标源（[`Branding/`](Branding/)）**：推荐全套 `16.png` … `1024.png`（像素边长与文件名一致）；或仅放 `1024.png` / `icon_1024x1024_master.png`，由脚本用 `sips` 生成其余槽位。
- **Asset Catalog**：[`AppIcon.appiconset/`](Sources/DiskCleanerApp/Resources/Assets.xcassets/AppIcon.appiconset/) 由 [`scripts/sync_app_icon_from_branding.sh`](scripts/sync_app_icon_from_branding.sh) 同步；[`scripts/package_mac_app.sh`](scripts/package_mac_app.sh) 在 `swift build` 前会自动执行。若只跑 `swift build` 且改过 `Branding`，请先手动执行该同步脚本。
- 槽位尺寸与规范见 [Apple App Icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)。

### 日常分发：只要 DMG

一般你只需要 **一条命令**（内部会自动先打好 `.app`，再刻 DMG）：

```bash
chmod +x scripts/create_dmg.sh
./scripts/create_dmg.sh
```

得到 `dist/DiskCleaner.dmg`；其中已调用 `package_mac_app.sh` 生成 `dist/DiskCleanerApp.app`。

**仅当你只要 `.app`、不要 DMG**（例如本地快速测安装包）时，再单独执行：

```bash
chmod +x scripts/package_mac_app.sh
./scripts/package_mac_app.sh
```

开发调试界面请继续用 **`swift run DiskCleanerApp`**，通常不必每次跑打包脚本。

**图标**：有完整 Xcode 且 `xcode-select` 指向它时，脚本会走 **`actool` → `Assets.car`**；否则走 **`iconutil` → `AppIcon.icns`**，**同样使用你提供的 `AppIcon.appiconset` 里那套 PNG**，不是图标有问题。终端里看到「未检测到 actool、使用 iconutil」是**正常说明**，不是报错。若导出图是「扩展名 .png、内容实为 JPEG」，脚本会用 `sips` 先转成真 PNG 再合成。仍无图标时重新打包后试访达 **⌘R** 刷新。想强制走 `actool` 可执行：`sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`。

在 **Xcode** 里新建 macOS App 时，也可把同一套 `AppIcon.appiconset` 拖进 **Assets.xcassets**。

## DMG 拖拽安装（给最终用户）

`create_dmg.sh` 会在临时目录里放入 **应用程序** 替身与 **安装说明.txt**，再用 `hdiutil` 生成压缩 DMG。

### 最终用户要做什么（装在你电脑上的朋友 / 你自己）

1. 双击挂载 DMG，把 **DiskCleanerApp** 拖到 **Applications**（应用程序）。
2. 第一次打开若被拦截：**终端**执行（路径按实际安装位置改）：

```bash
xattr -cr /Applications/DiskCleanerApp.app
```

然后再从「应用程序」里打开。也可试：**系统设置 → 隐私与安全性** 里对拦截提示点 **仍要打开**（视系统版本文案略有不同）。

说明：未做 **Developer ID 签名 + 公证** 时，从网盘/浏览器下载常会带 **隔离（quarantine）**，`xattr -cr` 是去掉扩展属性里与隔离相关的标记；请只对你**信任来源**的包这样做。长期给多人用建议走签名与公证，可少依赖终端。

## 大文件扫描页

- **大文件列表**：≥ 设定阈值的文件逐条展示，含路径说明（见下节规则）、访达、复制路径。
- **小文件概要**：低于阈值的体积按路径推断的 **应用/标识**（如 `com.google.Chrome`、`Caches` 下 bundle id 等）聚合成甜甜圈图；悬停扇区可看大小与占比；**点击扇区或图例** 可筛选下方目录明细（再点同一项可取消筛选）。「其余」为未进前十名的分组合并，不提供筛选。
- **小文件目录明细**：每个小文件只计入其**直接父目录**；表格按体积取 **Top 100** 父目录展示。筛选后仅显示与所选分组键一致的父目录，便于从概要定位到具体路径（例如 Chrome / Google 相关目录）。

## 路径说明（大文件列表）

规则由 [`Sources/DiskCleanerApp/Resources/path_label_rules.json`](Sources/DiskCleanerApp/Resources/path_label_rules.json) 配置：**按数组顺序首个匹配生效**。字段含义：

| 字段 | 说明 |
|------|------|
| `ifContains` | 路径须包含该子串 |
| `ifAlsoContains` | 可选，须同时包含 |
| `label` | 展示文案；可用 `{appName}`（沙盒/Group 解析出的应用名）、`{groupFolder}`（Group Containers 目录名） |
| `context` | 空：仅用 `label`；`container`：从 `…/Containers/<bundleId>/` 解析 `{appName}`；`groupResolved` / `groupFallback`：见 JSON 内同类条目 |

未匹配时说明列为「—」。若 Bundle 内 JSON 缺失，会使用代码内嵌的同款兜底规则。`NSWorkspace` 反查应用名仍在 Swift 中实现，无法单靠 JSON 表达。

## 构建与运行

需要 **Xcode 15+**（或自带 Swift 5.9+ 的工具链）与 **macOS 14+** 运行环境。

在仓库根目录执行：

```bash
cd DiskCleanerApp
swift build
swift run DiskCleanerApp
```

也可在 Xcode 中选择 **File → Open** 打开 `Package.swift`，选取 `DiskCleanerApp` 可执行目标后运行。

`.build/`、`dist/`、`.DS_Store` 等已写入 [`.gitignore`](.gitignore)，勿将本地构建产物与打包结果提交进仓库。

## 完全磁盘访问权限（Full Disk Access）

- 通过「选择文件夹」仅能获得用户授权目录的访问；若需扫描其他用户目录、部分系统路径或完整卷，多数情况下必须在 **系统设置 → 隐私与安全性 → 完全磁盘访问权限** 中勾选本应用。
- 应用内 **设置** 标签页提供「打开完全磁盘访问权限设置」按钮（跳转系统偏好设置 URL；若未来系统变更路径，请手动进入上述设置页）。
- 未授权时，枚举可能失败或大小为 0，界面会尽量在摘要或警告中提示。

## 分发策略：沙盒与 Mac App Store

- **Mac App Store + App Sandbox**：对任意用户路径的读写与删除限制严格，「一键清理」类能力通常受限；需额外使用安全作用域书签并可能仍无法覆盖全盘。
- **Developer ID + 公证（notarized）官网分发**：许多磁盘工具采用此方式，配合用户授予的完全磁盘访问，才能实现可靠的系统级扫描与移入废纸篓。
- 本仓库当前为 **SwiftPM 可执行目标**，未附带沙盒 entitlement；若上架商店，需单独配置 App Sandbox 并重新评估可清理路径与 UX。

## 开发缓存清单

规则文件位于 [Sources/DiskCleanerApp/Resources/dev_cache_rules.json](Sources/DiskCleanerApp/Resources/dev_cache_rules.json)。字段说明：

| 字段 | 说明 |
|------|------|
| `id` | 稳定标识，用于代码中跳过递归等特殊逻辑 |
| `path` | 支持 `~` 的路径 |
| `category` | `safeToDelete` / `useWithCaution` / `doNotDelete` |
| `title` / `description` | 界面展示用 |

仅 `safeToDelete` 且路径存在时提供「移入废纸篓」；`doNotDelete` 仅展示说明，不提供删除操作。

## 说明

- 体积统计未处理 APFS 克隆去重与硬链接去重，数值可能高于磁盘实际净占用。
- `application-support-generic` 规则故意不做递归体积计算，避免扫描整个 `Application Support` 导致长时间阻塞。
