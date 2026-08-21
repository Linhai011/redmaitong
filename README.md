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
| `database/` | MySQL 建库脚本（schema / 种子数据 / 练习查询） |
| `assets/diagrams/` | UML 与系统设计图 |
| `*.md` | 需求分析、UML 建模、API 接口、数据库设计、部署说明等文档 |

## 🔧 本地运行完整功能

完整版需要 Node.js（≥16）+ MySQL，详见 **[部署说明.md](部署说明.md)**：

1. 初始化数据库：按 `database/01_schema.sql`、`02_seed.sql` 建库灌数据
2. 配置并启动后端：`cd backend && npm install && cp .env.example .env && node server.js`
3. 浏览器访问 `http://localhost:3000`

测试账号（密码均为 `password`）：`zhangguan`（机构管理员，功能最全）、`admin`、`liguan`、`chenlaoshi`、`wangxiaoming`。
