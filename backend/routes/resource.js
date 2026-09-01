/**
 * 资源接口：
 *   GET  /v1/resource/search    跨机构检索
 *   GET  /v1/resource/:id       资源详情
 *   POST /v1/resource/upload    机构上传（multer 多文件）
 *   GET  /v1/resource/my-org    本机构资源
 */
const express = require('express');
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const pool = require('../db');
const { withTransaction } = require('../db');
const { optionalAuth, requireAuth, requireRole } = require('../auth');
const { ok, fail, toCamel, toCamelList, shareLevelName } = require('../map');

const router = express.Router();

// ---- multer 上传配置 ----
const UPLOAD_DIR = path.join(pool.getDataDir(), 'uploads');
if (!fs.existsSync(UPLOAD_DIR)) fs.mkdirSync(UPLOAD_DIR, { recursive: true });

const storage = multer.diskStorage({
  destination: function (req, file, cb) { cb(null, UPLOAD_DIR); },
  filename: function (req, file, cb) {
    // 用时间戳+随机数+原扩展名命名，避免中文文件名与重名问题
    var ext = path.extname(file.originalname);
    cb(null, Date.now() + '-' + Math.round(Math.random() * 1e9) + ext);
  }
});
const upload = multer({ storage: storage, limits: { fileSize: 500 * 1024 * 1024 } });

// 给资源列表里的每行附上 shareLevelName / resTypeName 等可读字段
function decorate(resource) {
  resource.shareLevelName = shareLevelName(resource.shareLevel);
  // resTypeName 已由 SQL 里 p.category_name 提供；若该资源直接挂一级分类，用 sub_category 兜底
  resource.resTypeName = resource.resTypeName || resource.subCategory;
  return resource;
}

// GET /v1/resource/search?keyword&orgId&resType&shareLevel&resourceYear&page&size
// 只展示已发布（audit_status=1）的资源；关键词用 LIKE（10 条数据够用）。
// 若你在 DB 里跑过 04_advanced.sql 建了全文索引，可把下方 LIKE 换成：
//   MATCH(r.title, r.meta_desc) AGAINST(? IN NATURAL LANGUAGE MODE)
// 这样能走倒排索引 + 相关度排序，性能更好。
router.get('/search', optionalAuth, async function (req, res) {
  try {
    var page = Math.max(1, parseInt(req.query.page) || 1);
    var size = Math.min(100, Math.max(1, parseInt(req.query.size) || 20));
    var offset = (page - 1) * size;

    var where = ['r.audit_status = 1'];
    var params = [];

    var keyword = (req.query.keyword || '').trim();
    if (keyword) {
      where.push('(r.title LIKE ? OR r.meta_desc LIKE ?)');
      params.push('%' + keyword + '%', '%' + keyword + '%');
    }
    if (req.query.orgId) { where.push('r.org_id = ?'); params.push(Number(req.query.orgId)); }
    // resType = 一级分类 id（1~6），资源挂在二级分类上，需 join 到父级过滤
    if (req.query.resType) {
      where.push('(p.category_id = ? OR r.category_id = ?)');
      params.push(Number(req.query.resType), Number(req.query.resType));
    }
    if (req.query.shareLevel) { where.push('r.share_level = ?'); params.push(Number(req.query.shareLevel)); }
    if (req.query.resourceYear) { where.push('r.resource_year = ?'); params.push(req.query.resourceYear); }

    var whereSql = where.join(' AND ');

    var [countRows] = await pool.query(
      'SELECT COUNT(*) AS cnt FROM resource r ' +
      'LEFT JOIN resource_category c ON c.category_id = r.category_id ' +
      'LEFT JOIN resource_category p ON p.category_id = c.parent_id ' +
      'WHERE ' + whereSql,
      params
    );
    var total = countRows[0].cnt;

    var [rows] = await pool.query(
      'SELECT r.resource_id, r.title, r.category_id, r.org_id, r.meta_desc, r.resource_year, ' +
      'r.share_level, r.cover_url, r.view_count, r.download_count, r.audit_status, r.created_at, ' +
      'o.org_name, c.category_name AS sub_category, p.category_name AS res_type_name, ' +
      'group_concat(DISTINCT t.tag_name) AS tags ' +
      'FROM resource r ' +
      'INNER JOIN org o ON o.org_id = r.org_id ' +
      'INNER JOIN resource_category c ON c.category_id = r.category_id ' +
      'LEFT JOIN resource_category p ON p.category_id = c.parent_id ' +
      'LEFT JOIN resource_tag rt ON rt.resource_id = r.resource_id ' +
      'LEFT JOIN tag t ON t.tag_id = rt.tag_id ' +
      'WHERE ' + whereSql +
      ' GROUP BY r.resource_id, r.title, r.category_id, r.org_id, r.meta_desc, r.resource_year, ' +
      ' r.share_level, r.cover_url, r.view_count, r.download_count, r.audit_status, r.created_at, ' +
      ' o.org_name, c.category_name, p.category_name ' +
      'ORDER BY r.view_count DESC LIMIT ? OFFSET ?',
      params.concat([size, offset])
    );

    var list = toCamelList(rows).map(decorate);
    ok(res, { total: total, page: page, size: size, list: list });
  } catch (e) {
    console.error(e);
    fail(res, 500, '检索资源失败');
  }
});

// GET /v1/resource/:id —— 详情 + tags[] + files[]
router.get('/:id', optionalAuth, async function (req, res) {
  try {
    var id = Number(req.params.id);
    var [rows] = await pool.query(
      'SELECT r.*, o.org_name, c.category_name AS sub_category, p.category_name AS res_type_name ' +
      'FROM resource r ' +
      'INNER JOIN org o ON o.org_id = r.org_id ' +
      'INNER JOIN resource_category c ON c.category_id = r.category_id ' +
      'LEFT JOIN resource_category p ON p.category_id = c.parent_id ' +
      'WHERE r.resource_id = ?',
      [id]
    );
    if (rows.length === 0) return fail(res, 404, '资源不存在');

    var [tags] = await pool.query(
      'SELECT t.tag_name FROM resource_tag rt INNER JOIN tag t ON t.tag_id = rt.tag_id WHERE rt.resource_id = ?',
      [id]
    );
    var [files] = await pool.query('SELECT * FROM resource_file WHERE resource_id = ? ORDER BY sort_order', [id]);

    var detail = toCamel(rows[0]);
    detail.shareLevelName = shareLevelName(detail.shareLevel);
    detail.resTypeName = detail.resTypeName || detail.subCategory;
    detail.tags = (tags || []).map(function (t) { return t.tag_name; });
    detail.files = toCamelList(files);
    ok(res, detail);
  } catch (e) {
    console.error(e);
    fail(res, 500, '查询资源详情失败');
  }
});

// POST /v1/resource/upload —— 机构上传（需 ORG_ADMIN / PLATFORM_ADMIN）
// multipart/form-data：title, resType(二级分类id), metaDesc, resourceYear, shareLevel, file(可多个)
router.post('/upload', requireAuth, requireRole('ORG_ADMIN', 'PLATFORM_ADMIN'), upload.array('file', 20), async function (req, res) {
  try {
    if (!req.user.orgId) return fail(res, 403, '个人用户不能上传资源');
    var b = req.body || {};
    if (!b.title || !b.resType || !b.metaDesc || !b.shareLevel) {
      return fail(res, 400, '标题、分类、简介、共享等级为必填');
    }
    var files = req.files || [];

    var resourceId = await withTransaction(async function (conn) {
      // 1) 写资源主表（audit_status=0 待审核）
      var [r] = await conn.query(
        'INSERT INTO resource (title, category_id, org_id, meta_desc, resource_year, share_level, audit_status) ' +
        'VALUES (?, ?, ?, ?, ?, ?, 0)',
        [b.title, Number(b.resType), req.user.orgId, b.metaDesc, b.resourceYear || null, Number(b.shareLevel)]
      );
      var rid = r.insertId;

      // 2) 每个上传文件写一条 resource_file
      for (var i = 0; i < files.length; i++) {
        var f = files[i];
        var fileType = path.extname(f.originalname).slice(1).toLowerCase();
        await conn.query(
          'INSERT INTO resource_file (resource_id, file_name, file_path, file_size, file_type, sort_order) ' +
          'VALUES (?, ?, ?, ?, ?, ?)',
          [rid, f.originalname, '/uploads/' + f.filename, f.size, fileType, i + 1]
        );
      }
      return rid;
    });

    ok(res, { resourceId: resourceId, uploadStatus: 'pending_audit' }, '资源已提交上传，等待审核');
  } catch (e) {
    console.error(e);
    fail(res, 500, '上传资源失败');
  }
});

// GET /v1/resource/my-org —— 本机构资源列表（机构管理用）
router.get('/my-org', requireAuth, async function (req, res) {
  try {
    if (!req.user.orgId) return fail(res, 400, '当前账号未绑定机构');
    var [rows] = await pool.query(
      'SELECT r.resource_id, r.title, r.share_level, r.view_count, r.download_count, r.audit_status, r.created_at, ' +
      'c.category_name AS sub_category ' +
      'FROM resource r LEFT JOIN resource_category c ON c.category_id = r.category_id ' +
      'WHERE r.org_id = ? ORDER BY r.resource_id DESC',
      [req.user.orgId]
    );
    ok(res, { list: toCamelList(rows).map(decorate) });
  } catch (e) {
    console.error(e);
    fail(res, 500, '查询本机构资源失败');
  }
});

module.exports = router;
