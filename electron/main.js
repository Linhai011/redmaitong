/**
 * 红脉通 · Electron 主进程
 * 职责：启动内嵌 Express 服务（随机端口）→ 打开窗口加载 http://127.0.0.1:<port>
 * 前端同源托管，API_BASE='/v1' 无需改动。
 */
const { app, BrowserWindow } = require('electron');

let mainWindow = null;
let server = null;

app.whenReady().then(function () {
  // 关键：在 require 后端之前注入数据目录（userData），
  // 让 db.js 把 redmaitong.db 和 uploads 建到可写目录（asar 只读，不能写）
  process.env.REDMAITONG_DATA_DIR = app.getPath('userData');

  const serverApp = require('../backend/server');
  server = serverApp.listen(0, '127.0.0.1', function () {
    const port = server.address().port;
    createWindow(port);
  });
});

function createWindow(port) {
  mainWindow = new BrowserWindow({
    width: 1366,
    height: 900,
    autoHideMenuBar: true,
    title: '红脉通 · 红色数字资源开放共享平台',
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false
    }
  });
  mainWindow.loadURL('http://127.0.0.1:' + port);
  mainWindow.on('closed', function () { mainWindow = null; });
}

app.on('window-all-closed', function () {
  if (server) { try { server.close(); } catch (e) {} }
  app.quit();
});

app.on('activate', function () {
  // macOS 点击 dock 图标时若无窗口则重建（Windows 下基本不会触发）
  if (mainWindow === null && server) {
    createWindow(server.address().port);
  }
});
