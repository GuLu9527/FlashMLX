# ⚡ FlashMLX

[English](README.md)

macOS 菜单栏轻量级 MLX 模型启动器，管理本地 MLX 模型的启停与配置。

**~2MB 体积** — 常驻菜单栏，一键启停推理服务。

## 功能

- 🔍 **自动扫描** `~/.cache/huggingface/hub/` 中的 MLX 模型
- 🚀 **一键启停** MLX 推理服务（`mlx_lm.server` / `mlx-openai-server`）
- 🧩 **嵌入模型支持** — 自动识别并通过 `/v1/embeddings` 提供嵌入服务
- ⚙️ **灵活配置** 上下文长度（2K–128K 快捷预设）、端口、模型类型、Python 路径
- 📊 **实时监控** 服务状态、运行时长、内存占用、健康检查
- 📋 **快捷操作** 一键复制 API 地址 / cURL 命令
-  **Python 验证** 在设置中验证 mlx-lm 安装状态
- 🚀 **开机自启** 通过 SMAppService 实现登录自启动
- 🪟 **可拆卸浮窗** Popover 可转为独立浮动窗口
- 🔔 **系统通知** 服务启动/停止/异常时发送系统通知
- 🌐 **中英双语** 跟随系统语言自动切换
- 🛡️ **进程管理** — 多实例防护、孤儿进程清理、端口冲突自动解决
- 🪶 **轻量原生** ~2MB，纯 Swift + SwiftUI，无 Electron

## 系统要求

- macOS 14.0+（Sonoma）
- Apple Silicon（M1/M2/M3/M4）
- Python 3.x + `mlx-lm`
- 嵌入模型需要：`mlx-openai-server`（`pip install mlx-openai-server`）

## 快速开始

### 1. 准备 Python 环境

```bash
python3 -m venv ~/mlx-env
~/mlx-env/bin/pip install mlx-lm

# 可选：嵌入模型支持
~/mlx-env/bin/pip install mlx-openai-server
```

### 2. 下载 MLX 模型

```bash
# 语言模型
~/mlx-env/bin/huggingface-cli download mlx-community/Qwen2.5-7B-Instruct-4bit

# 嵌入模型（可选）
~/mlx-env/bin/huggingface-cli download mlx-community/nomic-embed-text-v1.5-bf16
```

### 3. 编译运行

```bash
# 安装 XcodeGen（首次）
brew install xcodegen

# 生成 Xcode 工程
xcodegen generate

# 命令行编译
xcodebuild -project FlashMLX.xcodeproj -scheme FlashMLX -configuration Release build

# 或在 Xcode 中打开后按 ⌘R
open FlashMLX.xcodeproj
```

### 4. 使用

1. 点击菜单栏 ⚡ 图标
2. 从侧边栏选择模型
3. 按需调整配置（上下文长度、端口）
4. 点击 **启动** — 服务运行在 `http://localhost:8000/v1`

```bash
# 对话补全（语言模型）
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "default", "messages": [{"role": "user", "content": "你好"}]}'

# 文本嵌入（嵌入模型）
curl http://localhost:8000/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{"model": "default", "input": "你好世界"}'
```

## 项目结构

```
FlashMLX/
├── FlashMLXApp.swift               # @main 入口
├── AppDelegate.swift                # NSStatusBar + Popover + 图标状态 + 浮窗
├── Models/
│   ├── MLXModel.swift               # 本地模型数据结构
│   └── ServerConfig.swift           # 服务配置（Codable）
├── Services/
│   ├── ModelScanner.swift           # 扫描 HF 缓存（解析符号链接）
│   ├── ServerManager.swift          # 进程启停 + 日志 + 内存 + 健康检查 + 通知
│   └── ConfigManager.swift          # UserDefaults 持久化
├── Views/
│   ├── PopoverView.swift            # 主容器（Header + 侧边栏 + Tab）
│   ├── ModelListView.swift          # 模型列表 + 搜索过滤 + Badge
│   ├── ConfigView.swift             # 配置面板（上下文预设、端口、类型、Python）
│   ├── StatusView.swift             # 状态卡片 + 快捷操作
│   ├── LogView.swift                # 实时日志查看器
│   └── SettingsView.swift           # 开机自启、Python 验证、重置
├── en.lproj/Localizable.strings     # 英文
└── zh-Hans.lproj/Localizable.strings # 中文
```

## 菜单栏图标状态

| 颜色 | 含义 |
|------|------|
| 🟢 绿色 | 服务运行中 |
| 🟠 橙色 | 服务启动中 |
| 🔴 红色 | 错误 |
| ⚪ 灰色 | 已停止 |

## 技术决策

| 决策 | 选择 | 理由 |
|------|------|------|
| 窗口模式 | Menubar Popover | 启动器不需要全窗口 |
| 进程管理 | Foundation.Process | Swift 原生子进程控制 |
| LM 后端 | `mlx_lm.server` CLI | 复用推理引擎，只做 UI 壳 |
| 嵌入后端 | `mlx-openai-server` | 专用嵌入服务，提供 `/v1/embeddings` |
| 进程安全 | PID 锁 + 孤儿清理 | 防止重复启动，自动清理崩溃残留进程 |
| 模型发现 | 扫描 HF 缓存 | 用户已有模型直接可用 |
| 配置存储 | UserDefaults | macOS 原生，简单可靠 |
| 开机自启 | SMAppService | 现代 macOS API，无需 plist |
| 国际化 | Localizable.strings | 跟随系统语言，中英双语 |

## 许可证

MIT
