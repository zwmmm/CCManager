---
name: app-release
description: 使用本 skill 发布 macOS 应用。自动生成 CHANGELOG、递增版本号、提交代码并打 tag 推送到远程。
---

# App Release

发布 macOS 应用的标准流程：更新版本号 → 更新 CHANGELOG → 更新 release-notes.md → 提交代码 → 打 tag → 推送。

## 前置条件

- 项目使用 XcodeGen，版本信息存储在 `project.yml` 的 `MARKETING_VERSION` 和 `CURRENT_PROJECT_VERSION`
- 项目根目录存在 `CHANGELOG.md` 和 `release-notes.md`
- Git 仓库已有至少一个 tag（作为上一个版本基准）
- Sparkle 私钥已配置在 GitHub Secrets (`SPARKLE_PRIVATE_KEY`)
- 需要确保没有未提交的更改

## 发布流程

### Step 1: 检查 Git 状态

```bash
git status
git tag --list | tail -5
```

确保工作区干净，已有 tag 历史。

### Step 2: 确定版本号

从 `project.yml` 读取当前版本：

```bash
grep -E "MARKETING_VERSION|CURRENT_PROJECT_VERSION" project.yml
```

当前版本格式：
- `MARKETING_VERSION` = 市场版本（如 `1.0.0`）
- `CURRENT_PROJECT_VERSION` = 构建版本（整数，每次发布递增）

新版本规则：
- 如果自上次发布以来有 `feat:` 提交 → 递增 minor（如 1.0.0 → 1.1.0）
- 如果只有 `fix:` 或 `chore:` → 递增 patch（如 1.0.0 → 1.0.1）
- `CURRENT_PROJECT_VERSION` 每次发布都 +1

### Step 3: 更新版本号

修改 `project.yml`（XcodeGen 的源头配置）：

```bash
sed -i '' 's/MARKETING_VERSION: ".*"/MARKETING_VERSION: "X.Y.Z"/' project.yml
sed -i '' 's/CURRENT_PROJECT_VERSION: "[0-9]*"/CURRENT_PROJECT_VERSION: "N"/' project.yml

# 重新生成 project.pbxproj（确保本地构建也使用正确版本）
xcodegen generate
```

### Step 4: 更新 CHANGELOG

查找上一个 tag 到当前 HEAD 之间的所有提交：

```bash
git log v1.0.1..HEAD --oneline
```

分析所有提交，**用英文总结每类变更的核心内容并去掉与产品本身无关的提交，比如 CI,docs 等**，而非简单罗列 commit message。

```
## [New Version] - YYYY-MM-DD

### Features
- [English summary of feature changes]

### Bug Fixes
- [English summary of bug fixes]

### Others
- [English summary of chore/docs/refactor changes]
```

如果中间有 `BREAKING CHANGE:`，在 `##` 下方添加 `**Breaking Change**` 标记。

### Step 5: 更新 release-notes.md

这个文件的内容会用于：
- GitHub Release 的详情
- Sparkle 更新弹窗中的版本说明

内容应该是**这个版本**的 changelog 摘要（与 CHANGELOG.md 中该版本的内容一致）。

格式示例：
```markdown
### Features
- Add DMG packaging support for macOS distribution

### Bug Fixes
- Fix appcast.xml generation to use GitHub Release assets
```

### Step 6: 提交更改

```bash
git add project.yml CCManager.xcodeproj/project.pbxproj CHANGELOG.md release-notes.md
git commit -m "release: vX.Y.Z"
```

### Step 7: 创建并推送 tag

```bash
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin main && git push origin vX.Y.Z
```

### 验证

推送完成后验证：

```bash
git log --oneline -3
git tag --list | grep vX.Y.Z
```

## 错误处理

- 如果工作区不干净 → 先 `git stash` 或让用户确认已提交
- 如果没有找到上一个 tag → 提示用户指定基准 tag
- 如果推送失败 → 检查远程是否已存在该 tag
