/**
 * 个人中心与用户行为接口（挂在 /v1 下）：
 *   GET    /v1/favorite/list          我的收藏
 *   POST   /v1/favorite/:resourceId   收藏
 *   DELETE /v1/favorite/:resourceId   取消收藏
 *   GET    /v1/download/list          下载记录
 *   GET    /v1/history/list           浏览历史
 *   POST   /v1/browse/:resourceId     记录浏览（view_count +1）
 *   POST   /v1/download/:resourceId   记录下载（download_count +1）
 *
 * 计数说明：这里在【事务】里显式 UPDATE 计数。
 * 若你在 DB 里跑过 04_advanced.sql 的触发器 trg_download_count / trg_browse_count，
 * 二者会重复 +1 —— 二选一即可（本后端默认显式 UPDATE，自包含、不依赖触发器）。
 */
const express = require('express');
const pool = require('../db');
const { withTransaction } = require('../db');
const { requireAuth } = require('../auth');
const { ok, fail, toCamelList } = require('../map');

const router = express.Router();

// GET /v1/favorite/list
router.get('/favorite/list', requireAuth, async function (req, res) {
  try {
    var [rows] = await pool.query(
      'SELECT f.favorite_id, f.resource_id, f.created_at AS favorited_at, ' +
      'r.title, r.cover_url, r.view_count, r.download_count, o.org_name, c.category_name AS sub_category ' +
      'FROM favorite f ' +
      'INNER JOIN resource r ON r.resource_id = f.resource_id ' +
      'LEFT JOIN org o ON o.org_id = r.org_id ' +
      'LEFT JOIN resource_category c ON c.category_id = r.category_id ' +
      'WHERE f.user_id = ? ORDER BY f.created_at DESC',
      [req.user.userId]
    );
    ok(res, { list: toCamelList(rows) });
  } catch (e) {
    console.error(e);
    fail(res, 500, '查询收藏失败');
  }
});

// POST /v1/favorite/:resourceId —— 收藏（唯一键防重复）
router.post('/favorite/:resourceId', requireAuth, async function (req, res) {
  try {
    var rid = Number(req.params.resourceId);
    await pool.query('INSERT INTO favorite (user_id, resource_id) VALUES (?, ?)', [req.user.userId, rid]);
    ok(res, { resourceId: rid }, '已收藏');
  } catch (e) {
    if (e && e.code === 'ER_DUP_ENTRY') return ok(res, { resourceId: Number(req.params.resourceId) }, '已收藏过了');
    console.error(e);
    fail(res, 500, '收藏失败');
  }
});

// DELETE /v1/favorite/:resourceId —— 取消收藏
router.delete('/favorite/:resourceId', requireAuth, async function (req, res) {
  try {
    var rid = Number(req.params.resourceId);
    await pool.query('DELETE FROM favorite WHERE user_id = ? AND resource_id = ?', [req.user.userId, rid]);
    ok(res, { resourceId: rid }, '已取消收藏');
  } catch (e) {
    console.error(e);
    fail(res, 500, '取消收藏失败');
  }
});

// GET /v1/download/list
router.get('/download/list', requireAuth, async function (req, res) {
  try {
    var [rows] = await pool.query(
      'SELECT d.download_id, d.resource_id, d.ip, d.created_at, r.title, o.org_name ' +
      'FROM download_record d ' +
      'INNER JOIN resource r ON r.resource_id = d.resource_id ' +
      'LEFT JOIN org o ON o.org_id = r.org_id ' +
      'WHERE d.user_id = ? ORDER BY d.created_at DESC',
      [req.user.userId]
    );
    ok(res, { list: toCamelList(rows) });
  } catch (e) {
    console.error(e);
    fail(res, 500, '查询下载记录失败');
  }
});

// GET /v1/history/list
router.get('/history/list', requireAuth, async function (req, res) {
  try {
    var [rows] = await pool.query(
      'SELECT h.history_id, h.resource_id, h.created_at, r.title, o.org_name ' +
      'FROM browse_history h ' +
      'INNER JOIN resource r ON r.resource_id = h.resource_id ' +
      'LEFT JOIN org o ON o.org_id = r.org_id ' +
      'WHERE h.user_id = ? ORDER BY h.created_at DESC',
      [req.user.userId]
    );
    ok(res, { list: toCamelList(rows) });
  } catch (e) {
    console.error(e);
    fail(res, 500, '查询浏览历史失败');
  }
});

// POST /v1/browse/:resourceId —— 记录浏览（view_count +1）
router.post('/browse/:resourceId', requireAuth, async function (req, res) {
  try {
    var rid = Number(req.params.resourceId);
    await withTransaction(async function (conn) {
      await conn.query('INSERT INTO browse_history (user_id, resource_id) VALUES (?, ?)', [req.user.userId, rid]);
      await conn.query('UPDATE resource SET view_count = view_count + 1 WHERE resource_id = ?', [rid]);
    });
    ok(res, { resourceId: rid }, '已记录浏览');
  } catch (e) {
    console.error(e);
    fail(res, 500, '记录浏览失败');
  }
});

// POST /v1/download/:resourceId —— 记录下载（download_count +1）
router.post('/download/:resourceId', requireAuth, async function (req, res) {
  try {
    var rid = Number(req.params.resourceId);
    var ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress || null;
    await withTransaction(async function (conn) {
      await conn.query('INSERT INTO download_record (user_id, resource_id, ip) VALUES (?, ?, ?)', [req.user.userId, rid, ip]);
      await conn.query('UPDATE resource SET download_count = download_count + 1 WHERE resource_id = ?', [rid]);
    });
    ok(res, { resourceId: rid }, '已记录下载');
  } catch (e) {
    console.error(e);
    fail(res, 500, '记录下载失败');
  }
});

module.exports = router;
