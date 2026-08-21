/**
 * 数据库连接池（mysql2/promise）
 * 说明：
 *   - 所有 SQL 一律用 `?` 占位符（预编译），绝不拼接字符串，防 SQL 注入。
 *   - `connectionLimit` 控制并发连接数，适合课程设计规模。
 */
const mysql = require('mysql2/promise');
require('dotenv').config();

const pool = mysql.createPool({
  host: process.env.DB_HOST || '127.0.0.1',
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'redmaitong',
  waitForConnections: true,
  connectionLimit: 10,
  multipleStatements: false, // 安全起见禁用多语句执行
  dateStrings: true,         // DATETIME 直接按字符串返回（"2026-07-15 10:30:00"），避免时区转换
  charset: 'utf8mb4'
});

/**
 * 事务封装：把「多步 SQL 要么全成、要么全不成」打包成一个函数。
 * 用法：
 *   await withTransaction(async (conn) => {
 *     await conn.query('INSERT ...', [...]);
 *     await conn.query('UPDATE ...', [...]);
 *   });
 * 内部自动 commit，任何一步抛错自动 rollback，最后释放连接。
 */
async function withTransaction(fn) {
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const result = await fn(conn);
    await conn.commit();
    return result;
  } catch (e) {
    await conn.rollback();
    throw e;
  } finally {
    conn.release();
  }
}

module.exports = pool;
module.exports.withTransaction = withTransaction;
