# #573 扫描排除提示

2026-11-17，基线 `c333cf80a035020e38672f9c041fd907e4f65c67` 加本批未提交工作树，关联 songloft-org/songloft#573。

扫描组件调用后端 `POST /scan/validate`，选择目录后显示路径和命中规则，启动前重新检查。所有起点被排除或校验失败时不发起扫描；部分被排除时提示跳过目录。完成、取消或失败时保留后端返回的排除诊断。启动被后端拒绝时不再写入无法显示的 `status=error`，保留目录选择控件。设置解释扫描排除与歌单排除的差别，不提供临时豁免。

Linux amd64、Flutter 3.44.8 / Dart 3.12.2：853 项完整测试、4 项最终定向测试、静态分析、嵌入 Web 构建通过。隔离旧扫描页面时，新回归因缺少排除提示按预期失败；隔离副本最初的资源/依赖错误不计反向验证。日志 `/tmp/songloft-573-exclusions/flutter-{tests,targeted-final,analyze-delivery,web-build}.log`、`negative-flutter-final.log`；最终源码摘要见同目录 `source-identities.json`。

真实浏览器鼠标点击通过：登录、设置导航、目录勾选、全排除拒绝、混合扫描与结果显示；两次扫描按钮点击只产生一次后端扫描请求。`ui-flutter-results.json`、`ui-flutter.js`、`flutter-{blocked,result}-desktop.png`。后端契约及 HTTP 验证见[主仓库记录](https://github.com/songloft-org/songloft/blob/main/docs/issue-573-scan-exclusions.md)。Web 测试不等于 Windows 或移动原生包验收。Not run：Windows/Android/iOS 真机、报告人的 Docker 与私人曲库。用户随后授权提交、推送和父仓库 Issue 回复，实际提交与 CI 见证据目录 `delivery.json`；不创建正式版本。
