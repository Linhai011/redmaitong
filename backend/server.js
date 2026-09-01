/**
 * 红脉通后端入口（Express 应用）
 * - 作为桌面程序时：由 electron/main.js require 本文件拿到 app 并监听随机端口
 * - 独立调试时：node server.js 直接监听 3000 端口
 *
 * 职责：
 *   1. 托管前端静态文件（index.html / css / js）
 *   2. 托管上传的文件（/uploads/*）
 *   3. 挂载 /v1 下的各业务路由
 *   4. 全局 404 与错误处理
 */
const path = require('path');
const express = require('express');
const cors = require('cors');
const pool = require('./db');

const app = express();

// 跨域：本前端同源托管其实用不到，但万一有人用 file:// 直接打开 HTML 也能请求到
app.use(cors());

// 解析 JSON 请求体（登录/申请/审批等接口的 body）
app.use(express.json());

// 托管前端：只暴露 index.html / css / js，不暴露 backend（防止 node_modules 被下载）
app.get('/', function (req, res) { res.sendFile(path.join(__dirname, '..', 'index.html')); });
app.use('/css', express.static(path.join(__dirname, '..', 'css')));
app.use('/js', express.static(path.join(__dirname, '..', 'js')));

// 托管上传的文件（写目录在 userData/uploads，见 db.js 的 getDataDir）
app.use('/uploads', express.static(path.join(pool.getDataDir(), 'uploads')));

// 健康检查：判断 Node 进程是否活着、数据库是否能连通（排查用）
app.get('/v1/health', async function (req, res) {
  try {
    await pool.query('SELECT 1');
    res.json({ code: 200, msg: 'ok', data: { db: 'ok' }, timestamp: Date.now() });
  } catch (e) {
    res.status(500).json({ code: 500, msg: '数据库连接失败', data: null, timestamp: Date.now() });
  }
});

// 挂载业务路由
app.use('/v1/auth', require('./routes/auth'));
app.use('/v1/org', require('./routes/org'));
app.use('/v1/resource', require('./routes/resource'));
app.use('/v1/share', require('./routes/share'));
app.use('/v1/exhibition', require('./routes/exhibition'));
app.use('/v1/stats', require('./routes/stats'));
app.use('/v1', require('./routes/user')); // 收藏/下载/浏览等挂在 /v1 下

// 404
app.use(function (req, res) {
  res.status(404).json({ code: 404, msg: '接口不存在', data: null, timestamp: Date.now() });
});

// 全局错误处理（4 参数形式必须保留，Express 据此识别错误中间件）
app.use(function (err, req, res, next) {
  console.error(err);
  res.status(500).json({ code: 500, msg: '服务器内部错误', data: null, timestamp: Date.now() });
});

module.exports = app;

// 独立运行时才监听端口（桌面程序由 electron/main.js 监听随机端口）
if (require.main === module) {
  var PORT = Number(process.env.PORT || 3000);
  app.listen(PORT, function () {
    console.log('红脉通后端已启动：http://localhost:' + PORT);
    console.log('健康检查：http://localhost:' + PORT + '/v1/health');
  });
}
