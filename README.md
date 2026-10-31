# 短剧视界 / 全剧视界

Flutter 多端短剧应用。站源请求、解析、播放与下载均在设备上完成，不依赖旧项目或自建服务。

## 站源

默认版“短剧视界”仅含红果；`--all-sources` 全站源版“全剧视界”共 11 源：红果、黄豆、剧果、野果、帝果、黄果视频、黄果 AI、黄果旧版、青空、鬼片、韩小圈。

## 安装

GitHub Releases 提供两版安装包：Android APK（arm64-v8a、armeabi-v7a、x86_64）、未签名 IPA、Windows 便携版与安装版。iOS 未签名 IPA 需自行签名后安装。

## AltStore 订阅源

iOS 可通过 AltStore、SideStore 等兼容应用订阅安装，短剧视界与全剧视界两版都在源里，版本随 Release 自动更新：

<p align="center">
<a href="https://altdirect.app/?url=https://raw.githubusercontent.com/lukaschan/guoapp2/refs/heads/main/altstore.json" target="_blank">
<img src="https://raw.githubusercontent.com/bebound/AltGallery/master/assets/add-alt-source.png" alt="Add AltSource" width="200">
</a>
</p>

手动添加时填订阅源地址：`https://raw.githubusercontent.com/lukaschan/guoapp2/refs/heads/main/altstore.json`。全剧视界自 1.0.15 起使用独立 bundle ID，可与短剧视界同时安装；此前装过全剧视界 IPA 的需重新安装，数据不互通。

## 核心与同步

Go 核心引用上游 Xanerix/guoapp（`upstream/` submodule），fork 自有改动放在 `fork/`，构建时以覆盖层合入：新增文件直接拷入，改动以补丁打出，补丁打不上时构建直接失败。同步工作流每隔天检查上游，有更新时自动升版、推送并触发构建发版。

局域网互联入口目前隐藏：上游核心已移除 LAN 支持，相关文件保留，待移植后再恢复。

## 构建

发布构建走 GitHub Actions：推送到 main 即构建并发布 Release。本地构建入口见 `scripts/`（`build_android.py`、`build_ios.py`、`build_windows.py`）与 `.github/workflows/build.yml`。

## 说明

- 应用内不能切换版本：短剧视界与全剧视界是两个编译产物。
- 更新日志见 CHANGELOG.md，更早的记录见 GitHub Releases。
