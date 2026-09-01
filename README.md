# 红脉通 · 红色数字资源开放共享平台

> 全国多机构红色数字资源协同共享平台 —— 需求分析与原型设计（课程设计）

打破党史馆、革命纪念馆、地方档案馆、高校马院、文旅单位之间的资源壁垒，实现红色文化数字化资源的互联互通与协同共享。

## 🚀 在线预览

无需安装，点开即看（GitHub Pages，运行在**静态演示模式**，展示 mock 数据）：

🔗 **https://linhai011.github.io/redmaitong/**

> 静态演示模式下，「登录 / 上传 / 跨机构调取审批」等依赖后端数据库的功能不可用，页面会提示「后端未连接，当前为静态演示模式」，属正常降级。

## 🧩 项目结构

| 目录 | 说明 |
| --- | --- |
| `index.html` / `css/` / `js/` | 前端原型（纯静态，可独立打开） |
| `backend/` | Node.js + Express 后端（提供 `/v1/*` API） |
| `database/` | MySQL 建库脚本 + SQLite 初始化脚本（`sqlite_init.sql`，桌面版首次启动自动灌数据） |
| `assets/diagrams/` | UML 与系统设计图 |
| `*.md` | 需求分析、UML 建模、API 接口、数据库设计、部署说明等文档 |

## 🔧 本地运行（桌面版 · 独立运行，推荐）

已封装为**绿色免安装单文件**，双击即用，**无需安装 Node.js / MySQL / Python 等任何环境**（内置 SQLite 数据库 + 本地化 ECharts）：

1. 双击 `dist/红脉通.exe`，自动打开平台窗口，首次启动自动建库并灌入种子数据
2. 用下方测试账号登录即可体验完整功能（登录 / 上传 / 跨机构调取审批等）

> 数据与上传文件自动存放在系统用户目录 `%APPDATA%\redmaitong\`；删除该目录即可重置数据。

### 从源码构建 / 开发

如需改代码后重新打包：

```bash
npm install      # 安装依赖（已切国内镜像）
npm start        # 开发模式：Electron 直接运行
npm run dev      # 仅启动后端（node backend/server.js，端口 3000）
npm run dist     # 打包成 dist/红脉通.exe（electron-builder --win portable）
```

测试账号（密码均为 `password`）：`zhangguan`（机构管理员，功能最全）、`admin`（平台管理员）、`liguan`、`chenlaoshi`、`wangxiaoming`。
