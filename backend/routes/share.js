/**
 * 共享授权接口：
 *   POST /v1/share/apply       提交跨机构调取申请（事务）
 *   PUT  /v1/share/auth/audit  审批（事务）
 *   GET  /v1/share/auth/list   收到/发起的申请列表
 *
 * 说明：这里的「提交申请」「审批」都用【事务】把多步 SQL 包成原子操作，
 *      等价于 04_advanced.sql 里 sp_approve_auth 存储过程做的事——后端自包含，
 *      不依赖是否在 DB 里建过那个存储过程。
 */
const express = require('express');
const pool = require('../db');
const { withTransaction } = require('../db');
const { requireAuth, requireRole } = require('../auth');
const { ok, fail, toCamelList } = require('../map');

const router = express.Router();

// 使用期限：中文 → 编码
const DURATION_MAP = {
  '1个月': '1_month', '3个月': '3_months', '6个月': '6_months', '1年': '1_year', '长期使用': 'long_term'
};

// POST /v1/share/apply —— 提交调取申请
// body: { resourceId, applyPurpose, useDuration, contactPerson, contactPhone }
// targetOrgId 从 resource.org_id 反查；applyOrgId / applyUserId 取当前登录用户
router.post('/apply', requireAuth, async function (req, res) {
  try {
    var b = req.body || {};
    var resourceId = Number(b.resourceId);
    if (!resourceId || !b.applyPurpose) return fail(res, 400, '资源与申请用途为必填');
    if (!req.user.orgId) return fail(res, 403, '个人用户不能发起机构间调取申请');

    // 反查资源所属机构
    var [rs] = await pool.query('SELECT org_id FROM resource WHERE resource_id = ?', [resourceId]);
    if (rs.length === 0) return fail(res, 404, '资源不存在');
    var targetOrgId = rs[0].org_id;
    if (targetOrgId === req.user.orgId) return fail(res, 400, '不能申请本机构自己的资源');

    var authId = await withTransaction(async function (conn) {
      // 1) 写申请
      var [r] = await conn.query(
        'INSERT INTO share_auth (resource_id, apply_org_id, target_org_id, apply_user_id, apply_purpose, use_duration, contact_person, contact_phone, audit_status) ' +
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0)',
        [resourceId, req.user.orgId, targetOrgId, req.user.userId, b.applyPurpose,
         DURATION_MAP[b.useDuration] || b.useDuration || null, b.contactPerson || null, b.contactPhone || null]
      );
      var aid = r.insertId;

      // 2) 通知资源方管理员（targetOrg 的 ORG_ADMIN）
      var [admins] = await conn.query(
        'SELECT user_id FROM sys_user WHERE org_id = ? AND role = \'ORG_ADMIN\' LIMIT 1', [targetOrgId]
      );
      if (admins.length > 0) {
        await conn.query(
          'INSERT INTO notification (user_id, type, title, content, is_read) VALUES (?, ?, ?, ?, 0)',
          [admins[0].user_id, 'AUTH_AUDIT_RESULT', '收到新的共享申请', '有机构向您申请调取资源，请及时审批。']
        );
      }

      // 3) 写操作日志
      await conn.query(
        'INSERT INTO operation_log (user_id, action, target_type, target_id, detail) VALUES (?, ?, ?, ?, ?)',
        [req.user.userId, 'APPLY', 'share_auth', aid, '提交跨机构调取申请']
      );
      return aid;
    });

    ok(res, { authId: authId, resourceId: resourceId, applyOrgId: req.user.orgId, targetOrgId: targetOrgId, auditStatus: 0, auditStatusName: '待审批' }, '申请已提交');
  } catch (e) {
    console.error(e);
    fail(res, 500, '提交申请失败');
  }
});

// PUT /v1/share/auth/audit —— 审批（需 ORG_ADMIN / PLATFORM_ADMIN）
// body: { authId, auditResult(1通过/2驳回), auditRemark }
router.put('/auth/audit', requireAuth, requireRole('ORG_ADMIN', 'PLATFORM_ADMIN'), async function (req, res) {
  try {
    var b = req.body || {};
    var authId = Number(b.authId);
    var result = Number(b.auditResult);
    if (!authId || (result !== 1 && result !== 2)) return fail(res, 400, '参数不正确');

    await withTransaction(async function (conn) {
      // 1) 查出申请对应的资源与申请人
      var [rows] = await conn.query(
        'SELECT resource_id, apply_user_id FROM share_auth WHERE auth_id = ?', [authId]
      );
      if (rows.length === 0) throw new Error('申请不存在');
      var vResourceId = rows[0].resource_id;
      var vApplyUserId = rows[0].apply_user_id;

      // 2) 更新审批状态
      await conn.query(
        'UPDATE share_auth SET audit_status = ?, audit_result = ?, audit_remark = ?, audited_at = datetime(\'now\',\'localtime\') WHERE auth_id = ?',
        [result, result === 1 ? '同意授权使用' : '驳回', b.auditRemark || null, authId]
      );

      // 3) 通知申请人（有账号才发）
      if (vApplyUserId) {
        var [titles] = await conn.query('SELECT title FROM resource WHERE resource_id = ?', [vResourceId]);
        var title = titles.length ? titles[0].title : '';
        await conn.query(
          'INSERT INTO notification (user_id, type, title, content, is_read) VALUES (?, ?, ?, ?, 0)',
          [vApplyUserId, 'AUTH_AUDIT_RESULT',
           result === 1 ? '共享申请已通过' : '共享申请被驳回',
           (result === 1 ? '您申请的《' + title + '》已通过审批。' : '您申请的《' + title + '》被驳回。') +
           (b.auditRemark ? ' 审批意见：' + b.auditRemark : '')]
        );
      }

      // 4) 写审计日志
      await conn.query(
        'INSERT INTO operation_log (user_id, action, target_type, target_id, detail) VALUES (?, ?, ?, ?, ?)',
        [req.user.userId, 'AUDIT', 'share_auth', authId, '审批授权申请，结果=' + result]
      );
    });

    ok(res, { authId: authId, auditStatus: result, auditStatusName: result === 1 ? '已通过' : '已驳回' }, '审批完成');
  } catch (e) {
    console.error(e);
    fail(res, 500, '审批失败');
  }
});

// GET /v1/share/auth/list?type=received|applied&auditStatus
// received = 我机构收到的申请（target_org_id = 当前机构）
// applied  = 我机构发起的申请（apply_org_id = 当前机构）
router.get('/auth/list', requireAuth, async function (req, res) {
  try {
    if (!req.user.orgId) return fail(res, 400, '当前账号未绑定机构');
    var type = req.query.type === 'applied' ? 'applied' : 'received';
    var where = type === 'received' ? 's.target_org_id = ?' : 's.apply_org_id = ?';
    var params = [req.user.orgId];
    if (req.query.auditStatus !== undefined && req.query.auditStatus !== '') {
      where += ' AND s.audit_status = ?';
      params.push(Number(req.query.auditStatus));
    }

    var [rows] = await pool.query(
      'SELECT s.auth_id, s.resource_id, s.apply_org_id, s.target_org_id, s.apply_purpose, s.use_duration, ' +
      's.audit_status, s.audit_remark, s.created_at, s.audited_at, ' +
      'r.title AS resource_title, a.org_name AS apply_org_name, t.org_name AS target_org_name ' +
      'FROM share_auth s ' +
      'INNER JOIN resource r ON r.resource_id = s.resource_id ' +
      'INNER JOIN org a ON a.org_id = s.apply_org_id ' +
      'INNER JOIN org t ON t.org_id = s.target_org_id ' +
      'WHERE ' + where + ' ORDER BY s.created_at DESC',
      params
    );
    ok(res, { list: toCamelList(rows) });
  } catch (e) {
    console.error(e);
    fail(res, 500, '查询申请列表失败');
  }
});

module.exports = router;
