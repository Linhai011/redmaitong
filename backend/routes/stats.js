/**
 * 数据统计接口：GET /v1/stats/platform、GET /v1/stats/org
 * 供首页数据块与仪表盘（ECharts）使用。
 */
const express = require('express');
const pool = require('../db');
const { optionalAuth, requireAuth } = require('../auth');
const { ok, fail, toCamel, toCamelList } = require('../map');

const router = express.Router();

// GET /v1/stats/platform —— 平台整体统计
// 返回：总量、资源类型分布(饼图)、机构贡献排行(柱状图)、月度趋势(折线图)
router.get('/platform', optionalAuth, async function (req, res) {
  try {
    // 1) 总量
    var [totals] = await pool.query(
      'SELECT (SELECT COUNT(*) FROM org) AS total_orgs, ' +
      '(SELECT COUNT(*) FROM resource) AS total_resources, ' +
      '(SELECT COUNT(*) FROM exhibition) AS total_exhibitions, ' +
      '(SELECT COALESCE(SUM(view_count),0) FROM resource) AS total_views, ' +
      '(SELECT COALESCE(SUM(download_count),0) FROM resource) AS total_downloads'
    );

    // 2) 资源类型分布（按一级分类分组）
    var [typeDist] = await pool.query(
      'SELECT COALESCE(p.category_name, c.category_name) AS name, COUNT(*) AS value ' +
      'FROM resource r ' +
      'INNER JOIN resource_category c ON c.category_id = r.category_id ' +
      'LEFT JOIN resource_category p ON p.category_id = c.parent_id ' +
      'GROUP BY COALESCE(p.category_name, c.category_name)'
    );

    // 3) 机构贡献排行（Top 5，含 1级/2级共享数）
    var [orgRank] = await pool.query(
      'SELECT o.org_name, COUNT(r.resource_id) AS resource_count, ' +
      'COALESCE(SUM(CASE WHEN r.share_level = 1 THEN 1 ELSE 0 END),0) AS level1, ' +
      'COALESCE(SUM(CASE WHEN r.share_level = 2 THEN 1 ELSE 0 END),0) AS level2 ' +
      'FROM org o LEFT JOIN resource r ON r.org_id = o.org_id ' +
      'GROUP BY o.org_id, o.org_name ORDER BY resource_count DESC LIMIT 5'
    );

    // 4) 月度趋势：上传量 + 共享申请量，按月份合并
    var [uploadRows] = await pool.query(
      'SELECT DATE_FORMAT(created_at, \'%Y-%m\') AS month, COUNT(*) AS cnt FROM resource GROUP BY month ORDER BY month'
    );
    var [shareRows] = await pool.query(
      'SELECT DATE_FORMAT(created_at, \'%Y-%m\') AS month, COUNT(*) AS cnt FROM share_auth GROUP BY month ORDER BY month'
    );
    var shareMap = {};
    shareRows.forEach(function (r) { shareMap[r.month] = r.cnt; });
    var monthlyTrend = uploadRows.map(function (r) {
      return { month: r.month, uploadCount: r.cnt, shareCount: shareMap[r.month] || 0 };
    });

    ok(res, {
      totals: toCamel(totals[0]),
      resTypeDist: typeDist,
      orgRank: toCamelList(orgRank),
      monthlyTrend: monthlyTrend
    });
  } catch (e) {
    console.error(e);
    fail(res, 500, '查询平台统计失败');
  }
});

// GET /v1/stats/org?orgId —— 机构协同统计（默认当前登录机构）
router.get('/org', requireAuth, async function (req, res) {
  try {
    var orgId = Number(req.query.orgId) || req.user.orgId;
    if (!orgId) return fail(res, 400, '缺少机构参数');

    var [summary] = await pool.query(
      'SELECT o.org_id, o.org_name, COUNT(r.resource_id) AS total_resources, ' +
      'COALESCE(SUM(r.view_count),0) AS total_views, COALESCE(SUM(r.download_count),0) AS total_downloads, ' +
      '(SELECT COUNT(*) FROM share_auth WHERE target_org_id = ?) AS share_count ' +
      'FROM org o LEFT JOIN resource r ON r.org_id = o.org_id WHERE o.org_id = ? GROUP BY o.org_id, o.org_name',
      [orgId, orgId]
    );
    if (summary.length === 0) return fail(res, 404, '机构不存在');

    var [shareLevelDist] = await pool.query(
      'SELECT share_level, COUNT(*) AS cnt FROM resource WHERE org_id = ? GROUP BY share_level', [orgId]
    );
    var dist = { level1: 0, level2: 0, level3: 0 };
    shareLevelDist.forEach(function (r) { dist['level' + r.share_level] = r.cnt; });

    ok(res, { summary: toCamel(summary[0]), shareLevelDist: dist });
  } catch (e) {
    console.error(e);
    fail(res, 500, '查询机构统计失败');
  }
});

module.exports = router;
