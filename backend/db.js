/**
 * 数据库连接层（SQLite 版，使用 Node 内置 node:sqlite，零原生编译）
 * 把 MySQL 时代的接口原样保留，让所有路由文件无感知迁移：
 *   - pool.query(sql, params) -> 返回 [rows]（SELECT）或 [{ insertId, affectedRows }]（写操作）
 *   - withTransaction(fn)     -> 事务，fn 收到 conn，conn.query 与 pool.query 同接口
 *
 * 说明：
 *   - 桌面打包时由 electron/main.js 注入 REDMAITONG_DATA_DIR（userData 目录），
 *     开发时回退到项目下的 data/ 目录。
 *   - 首次启动（org 表不存在）会自动执行 ../database/sqlite_init.sql 建库灌种子数据。
 */
const { DatabaseSync } = require('node:sqlite');
const fs = require('fs');
const path = require('path');

// 数据目录：桌面打包时用 userData；开发时用项目下 data/
const DATA_DIR = process.env.REDMAITONG_DATA_DIR || path.join(__dirname, '..', 'data');
const DB_PATH = path.join(DATA_DIR, 'redmaitong.db');
const INIT_SQL_PATH = path.join(__dirname, '..', 'database', 'sqlite_init.sql');

if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });

const db = new DatabaseSync(DB_PATH);

// 首次启动：org 表不存在则建库灌种子数据（事务内原子完成，失败回滚下次重试）
db.exec('PRAGMA foreign_keys = OFF');
const hasTables = db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='org'").get();
if (!hasTables) {
  const initSql = fs.readFileSync(INIT_SQL_PATH, 'utf8');
  db.exec('BEGIN');
  try {
    db.exec(initSql);
    db.exec('COMMIT');
  } catch (e) {
    db.exec('ROLLBACK');
    throw e;
  }
}
db.exec('PRAGMA foreign_keys = ON');

// SELECT / WITH / PRAGMA 视为查询；其余（INSERT/UPDATE/DELETE/...）视为写操作
function isSelect(sql) {
  var s = String(sql).trim().toUpperCase();
  return s.startsWith('SELECT') || s.startsWith('WITH') || s.startsWith('PRAGMA');
}

// 把 SQLite 的“唯一约束冲突”错误归一化成 MySQL 的 ER_DUP_ENTRY，
// 让 routes/auth.js、routes/user.js 里 `e.code === 'ER_DUP_ENTRY'` 的判断原样可用。
function normalizeError(e) {
  if (!e) return e;
  var unique =
    (typeof e.errcode === 'number' && (e.errcode === 2067 || e.errcode === 1555)) ||
    e.code === 'SQLITE_CONSTRAINT_UNIQUE' ||
    e.code === 'SQLITE_CONSTRAINT_PRIMARYKEY' ||
    (e.message && e.message.indexOf('UNIQUE constraint failed') !== -1);
  if (unique) {
    var err = new Error(e.message);
    err.code = 'ER_DUP_ENTRY';
    return err;
  }
  return e;
}

function query(sql, params) {
  try {
    var stmt = db.prepare(sql);
    var p = Array.isArray(params) ? params : (params === undefined || params === null ? [] : [params]);
    if (isSelect(sql)) {
      return [stmt.all.apply(stmt, p)];
    }
    var info = stmt.run.apply(stmt, p);
    return [{ insertId: Number(info.lastInsertRowid), affectedRows: Number(info.changes) }];
  } catch (e) {
    throw normalizeError(e);
  }
}

// 事务：单连接下用串行队列，避免多个请求的 BEGIN/COMMIT 相互穿插
var txTail = Promise.resolve();
function withTransaction(fn) {
  var conn = { query: query };
  var run = txTail.then(function () {
    db.exec('BEGIN');
    return Promise.resolve()
      .then(function () { return fn(conn); })
      .then(function (result) { db.exec('COMMIT'); return result; },
            function (err) { db.exec('ROLLBACK'); throw normalizeError(err); });
  });
  txTail = run.then(function () {}, function () {});
  return run;
}

const pool = { query: query, withTransaction: withTransaction, getDataDir: function () { return DATA_DIR; } };
module.exports = pool;
module.exports.withTransaction = withTransaction;
