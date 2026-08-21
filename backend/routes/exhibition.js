/**
 * 展馆接口：GET /v1/exhibition/list、GET /v1/exhibition/:id
 */
const express = require('express');
const pool = require('../db');
const { optionalAuth } = require('../auth');
const { ok, fail, toCamel, toCamelList } = require('../map');

const router = express.Router();

// GET /v1/exhibition/list?status&orgId —— 展馆列表（含参与机构数、展品数）
router.get('/list', optionalAuth, async function (req, res) {
  try {
    var where = [];
    var params = [];
    if (req.query.status !== undefined && req.query.status !== '') { where.push('e.status = ?'); params.push(Number(req.query.status)); }
    if (req.query.orgId) {
      where.push('e.exhibition_id IN (SELECT exhibition_id FROM exhibition_org WHERE org_id = ?)');
      params.push(Number(req.query.orgId));
    }
    var whereSql = where.length ? 'WHERE ' + where.join(' AND ') : '';

    var [rows] = await pool.query(
      'SELECT e.exhibition_id, e.exhibition_name, e.description, e.cover_url, e.status, e.published_at, ' +
      'COUNT(DISTINCT eo.org_id) AS org_count, COUNT(DISTINCT er.resource_id) AS resource_count ' +
      'FROM exhibition e ' +
      'LEFT JOIN exhibition_org eo ON eo.exhibition_id = e.exhibition_id ' +
      'LEFT JOIN exhibition_resource er ON er.exhibition_id = e.exhibition_id ' +
      whereSql +
      ' GROUP BY e.exhibition_id ORDER BY e.exhibition_id',
      params
    );
    ok(res, { list: toCamelList(rows) });
  } catch (e) {
    console.error(e);
    fail(res, 500, '查询展馆列表失败');
  }
});

// GET /v1/exhibition/:id —— 展馆详情 + 参与机构 + 展品资源
router.get('/:id', optionalAuth, async function (req, res) {
  try {
    var id = Number(req.params.id);
    var [rows] = await pool.query('SELECT * FROM exhibition WHERE exhibition_id = ?', [id]);
    if (rows.length === 0) return fail(res, 404, '展馆不存在');

    var [orgs] = await pool.query(
      'SELECT o.org_id, o.org_name FROM exhibition_org eo INNER JOIN org o ON o.org_id = eo.org_id WHERE eo.exhibition_id = ?',
      [id]
    );
    var [resources] = await pool.query(
      'SELECT er.resource_id, r.title, o.org_name FROM exhibition_resource er ' +
      'INNER JOIN resource r ON r.resource_id = er.resource_id ' +
      'INNER JOIN org o ON o.org_id = r.org_id ' +
      'WHERE er.exhibition_id = ? ORDER BY er.sort_order',
      [id]
    );

    var detail = toCamel(rows[0]);
    detail.orgs = toCamelList(orgs);
    detail.resources = toCamelList(resources);
    ok(res, detail);
  } catch (e) {
    console.error(e);
    fail(res, 500, '查询展馆详情失败');
  }
});

module.exports = router;
