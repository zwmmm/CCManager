# Codex OAuth Provider 支持设计

## 1. 概述

为 CCManager 添加第三种 Provider 类型：**Codex OAuth**。

用户可以通过 OAuth 方式登录 ChatGPT 账号（Plus/Pro），替代 API Key 认证。支持多账号管理，Token 持久化存储在 SQLite 中，仅在激活时写入本地配置文件。

## 2. Provider 类型

### 2.1 ProviderType 枚举变更

```swift
enum ProviderType: String, CaseIterable, Identifiable, Codable {
    case claudeCode = "Claude Code"
    case codex = "Codex"
    case codexOAuth = "Codex OAuth"  // 新增
}
```

### 2.2 Provider 模型变更

```swift
struct Provider: Identifiable, Equatable, Codable {
    var id: UUID
    var name: String
    var type: ProviderType
    var apiKey: String?           // Codex OAuth 模式下为 nil
    var baseUrl: String
    var model: String?
    // ... 其他现有字段 ...

    // Codex OAuth 专用字段（仅 codexOAuth 类型使用）
    var oauthAccountId: String?       // ChatGPT 账号 ID
    var oauthAccessToken: String?     // OAuth access_token
    var oauthRefreshToken: String?    // OAuth refresh_token
    var oauthIdToken: String?         // OAuth id_token
    var oauthTokenExpiry: Date?       // access_token 过期时间
    var oauthDisplayName: String?     // ChatGPT 用户显示名
}
```

## 3. 数据库 Schema

### 3.1 新增列

```sql
ALTER TABLE providers ADD COLUMN oauth_account_id TEXT;
ALTER TABLE providers ADD COLUMN oauth_access_token TEXT;
ALTER TABLE providers ADD COLUMN oauth_refresh_token TEXT;
ALTER TABLE providers ADD COLUMN oauth_id_token TEXT;
ALTER TABLE providers ADD COLUMN oauth_token_expiry TEXT;
ALTER TABLE providers ADD COLUMN oauth_display_name TEXT;
```

## 4. OAuth 登录流程

### 4.1 Device Code 流程

```
用户点击"登录"
  → 执行 `codex login --device-auth`
  → 解析 stdout，提取：
      - user_code: "U9CQ-MFLJ1"
      - verification_uri: "https://auth.openai.com/codex/device"
  → 展示授权信息给用户（弹窗显示链接和验证码）
  → 轮询检查 ~/.codex/auth.json 是否更新（每 5 秒一次，最多 15 分钟）
  → 授权成功后解析 auth.json，提取 tokens
  → 保存到 SQLite
  → 关闭登录弹窗
```

### 4.2 输出解析

`codex login --device-auth` 输出格式：

```
Welcome to Codex [v0.122.0]
OpenAI's command-line coding agent

Follow these steps to sign in with ChatGPT using device code authorization:

1. Open this link in your browser and sign in to your account
   https://auth.openai.com/codex/device

2. Enter this one-time code (expires in 15 minutes)
   U9CQ-MFLJ1
```

解析规则：
- URL：`https://auth.openai.com/codex/device`（固定）
- Code：正则匹配 `[A-Z0-9]{4}-[A-Z0-9]{4}`

### 4.3 Token 轮询

授权成功后，Codex CLI 会写入 `~/.codex/auth.json`。轮询检测该文件是否包含 `"auth_mode": "chatgpt"` 来判断授权完成。

## 5. 激活流程（写入本地配置）

### 5.1 auth.json 格式（OAuth 模式）

```json
{
  "auth_mode": "chatgpt",
  "OPENAI_API_KEY": null,
  "tokens": {
    "id_token": "<oauth_id_token>",
    "access_token": "<oauth_access_token>",
    "refresh_token": "<oauth_refresh_token>",
    "account_id": "<oauth_account_id>"
  },
  "last_refresh": "<ISO8601 timestamp>"
}
```

### 5.2 config.toml 格式（OAuth 模式）

仅写入 model 字段，不写入 `model_provider` 相关内容：

```toml
model = "gpt-4o"
```

**注意**：如果已存在 `model_provider` 相关配置，保留原样不做删除。

### 5.3 原子写入

auth.json 和 config.toml 均使用原子写入（先写临时文件再 rename），防止数据损坏。

## 6. Token 刷新

- access_token 有效期约 1 小时
- Provider 编辑页面提供"刷新"按钮
- 刷新成功后更新 SQLite 中的 `oauthAccessToken`、`oauthRefreshToken`、`oauthTokenExpiry`
- 刷新失败（如 refresh_token 过期）提示用户重新登录

## 7. UI 设计

### 7.1 Add/Edit Provider（codexOAuth 类型）

```
┌─────────────────────────────────────────────────┐
│ Provider Name    [My ChatGPT Account]           │
│ Type             [Codex OAuth ▼]                │
├─────────────────────────────────────────────────┤
│ Account                                        │
│ ┌───────────────────────────────────────────┐   │
│ │ [未登录]                    [登录 ChatGPT] │   │
│ └───────────────────────────────────────────┘   │
│                                              或  │
│ ┌───────────────────────────────────────────┐   │
│ │ ✓ 已登录: san...@gmail.com (Plus)         │   │
│ │   [刷新 Token]              [登出]        │   │
│ └───────────────────────────────────────────┘   │
├─────────────────────────────────────────────────┤
│ Base URL    [https://api.openai.com/v1]        │
│ Model       [gpt-4o]                          │
├─────────────────────────────────────────────────┤
│                            [Cancel]  [Save]    │
└─────────────────────────────────────────────────┘
```

### 7.2 登录弹窗

```
┌─────────────────────────────────────────────────┐
│           登录 ChatGPT 账号                     │
├─────────────────────────────────────────────────┤
│  1. 在浏览器中打开以下链接并登录：              │
│     https://auth.openai.com/codex/device        │
│     [复制链接]                                  │
│                                                 │
│  2. 输入验证码：                                │
│        ┌─────────────────┐                      │
│        │   U9CQ-MFLJ1    │  [复制验证码]        │
│        └─────────────────┘                      │
│                                                 │
│  ⏳ 等待授权中...（请在浏览器中完成登录）        │
│                                                 │
│                            [取消]               │
└─────────────────────────────────────────────────┘
```

### 7.3 Provider 详情预览

```
已登录: san...@gmail.com (ChatGPT Plus)
```

## 8. 新增 Shared 层文件

```
Sources/Shared/
  ├── CodexOAuthLoginParser.swift   // 解析 codex login --device-auth 输出
  └── ConfigWriter+CodexOAuth.swift // Codex OAuth auth.json / config.toml 写入
```

## 9. 实现计划

### Phase 1：数据模型
- [ ] 扩展 ProviderType 枚举
- [ ] 扩展 Provider 模型
- [ ] 数据库迁移脚本

### Phase 2：OAuth 登录
- [ ] 实现 CodexOAuthLoginParser（输出解析）
- [ ] 实现登录弹窗 UI
- [ ] 实现轮询等待逻辑
- [ ] Token 提取并存储到 SQLite

### Phase 3：激活与配置写入
- [ ] 实现 ConfigWriter+CodexOAuth
- [ ] 修改 ConfigWriter 判断逻辑（根据 type 选择写入方式）
- [ ] 原子写入实现

### Phase 4：Token 刷新
- [ ] 刷新按钮 UI
- [ ] 刷新逻辑实现
- [ ] SQLite 更新

### Phase 5: UI 整合
- [ ] Add/Edit Provider 弹窗集成
- [ ] Provider 详情预览
- [ ] 测试完整流程
