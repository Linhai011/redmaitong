/**
 * 机构接口：GET /v1/org/list、GET /v1/org/info、POST /v1/org/apply
 */
const express = require('express');
const pool = require('../db');
const { requireAuth, optionalAuth } = require('../auth');
const { ok, fail, toCamel, toCamelList } = require('../map');

const router = express.Router();

// 机构类型：中文名 → 编码（前端下拉可能传中文，这里兜底转码）
const ORG_TYPE_MAP = {
  '综合档案馆': 'ARCH',
  '革命纪念馆': 'MEM',
  '党史研究室': 'HIST',
  '高校马克思主义学院': 'MARX',
  '文旅红色教育基地': 'CULT'
};

// GET /v1/org/list?page&size&orgType&status
// 机构列表，LEFT JOIN 统计每家机构的资源数（resourceCount）
router.get('/list', optionalAuth, async function (req, res) {
  try {
    var page = Math.max(1, parseInt(req.query.page) || 1);
    var size = Math.min(100, Math.max(1, parseInt(req.query.size) || 20));
    var offset = (page - 1) * size;

    var where = [];
    var params = [];
    if (req.query.orgType) { where.push('o.org_type = ?'); params.push(req.query.orgType); }
    if (req.query.status !== undefined && req.query.status !== '') { where.push('o.status = ?'); params.push(Number(req.query.status)); }
    var whereSql = where.length ? 'WHERE ' + where.join(' AND ') : '';

    var [countRows] = await pool.query('SELECT COUNT(*) AS cnt FROM org o ' + whereSql, params);
    var total = countRows[0].cnt;

    var [rows] = await pool.query(
      'SELECT o.org_id, o.org_name, o.org_type, o.status, o.address, o.contact_name, o.contact_phone, o.created_at, ' +
      'COUNT(r.resource_id) AS resource_count ' +
      'FROM org o LEFT JOIN resource r ON r.org_id = o.org_id ' +
      whereSql +
      ' GROUP BY o.org_id, o.org_name, o.org_type, o.status, o.address, o.contact_name, o.contact_phone, o.created_at ' +
      'ORDER BY o.org_id LIMIT ? OFFSET ?',
      params.concat([size, offset])
    );
    ok(res, { total: total, page: page, size: size, list: toCamelList(rows) });
  } catch (e) {
    console.error(e);
    fail(res, 500, '查询机构列表失败');
  }
});

// GET /v1/org/info —— 当前登录用户所属机构的信息（上传页自动填充"来源机构"用）
router.get('/info', requireAuth, async function (req, res) {
  try {
    if (!req.user.orgId) return fail(res, 400, '当前账号未绑定机构');
    var [rows] = await pool.query('SELECT * FROM org WHERE org_id = ?', [req.user.orgId]);
    if (rows.length === 0) return fail(res, 404, '机构不存在');
    ok(res, toCamel(rows[0]));
  } catch (e) {
    console.error(e);
    fail(res, 500, '查询机构信息失败');
  }
});

// POST /v1/org/apply —— 机构入驻申请（INSERT org，status=0 待审核）
// body: { orgName, orgType, creditCode, orgAddress, contactName, contactPhone, email, orgDesc, applyReason }
router.post('/apply', async function (req, res) {
  try {
    var b = req.body || {};
    if (!b.orgName || !b.orgType || !b.creditCode) return fail(res, 400, '机构名称、机构类型、信用代码为必填');

    var orgType = ORG_TYPE_MAP[b.orgType] || b.orgType; // 中文兜底转码，若已是编码则原样用
    var [r] = await pool.query(
      'INSERT INTO org (org_name, org_type, credit_code, address, contact_name, contact_phone, email, description, apply_reason, api_level, status) ' +
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1, 0)',
      [b.orgName, orgType, b.creditCode, b.orgAddress || null, b.contactName || null, b.contactPhone || null,
       b.email || null, b.orgDesc || null, b.applyReason || null]
    );
    ok(res, { orgId: r.insertId, status: 0, statusName: '待审核' }, '入驻申请已提交，等待平台审核');
  } catch (e) {
    console.error(e);
    fail(res, 500, '提交入驻申请失败');
  }
});

module.exports = router;
