/**
 * 用户认证接口：POST /v1/auth/login、POST /v1/auth/register
 */
const express = require('express');
const bcrypt = require('bcryptjs');
const pool = require('../db');
const { signToken } = require('../auth');
const { ok, fail } = require('../map');

const router = express.Router();

// POST /v1/auth/login
// body: { username, password }
// 成功返回 JWT + 用户信息；密码用 bcrypt 比对（绝不存明文）
router.post('/login', async function (req, res) {
  try {
    var body = req.body || {};
    var username = body.username;
    var password = body.password;
    if (!username || !password) return fail(res, 400, '用户名和密码不能为空');

    var [rows] = await pool.query(
      'SELECT u.user_id, u.username, u.password_hash, u.role, u.org_id, u.status, o.org_name ' +
      'FROM sys_user u LEFT JOIN org o ON o.org_id = u.org_id WHERE u.username = ?',
      [username]
    );
    if (rows.length === 0) return fail(res, 401, '用户名或密码错误');

    var user = rows[0];
    if (user.status === 0) return fail(res, 403, '账号已被禁用');

    var match = await bcrypt.compare(password, user.password_hash);
    if (!match) return fail(res, 401, '用户名或密码错误');

    ok(res, {
      userId: user.user_id,
      username: user.username,
      role: user.role,
      orgId: user.org_id,
      orgName: user.org_name || null,
      token: signToken(user),
      expireTime: Date.now() + 7 * 24 * 3600 * 1000
    });
  } catch (e) {
    console.error(e);
    fail(res, 500, '登录失败');
  }
});

// POST /v1/auth/register
// body: { username, password, phone, email, role, orgId }
// 密码先 bcrypt 哈希再入库（对齐 API 契约，当前原型暂无注册表单）
router.post('/register', async function (req, res) {
  try {
    var body = req.body || {};
    var username = body.username;
    var password = body.password;
    if (!username || !password) return fail(res, 400, '用户名和密码不能为空');

    var hash = await bcrypt.hash(password, 10);
    var [r] = await pool.query(
      'INSERT INTO sys_user (username, password_hash, phone, email, role, org_id, status) ' +
      'VALUES (?, ?, ?, ?, ?, ?, 1)',
      [username, hash, body.phone || null, body.email || null, body.role || 'INDIVIDUAL', body.orgId || null]
    );
    ok(res, { userId: r.insertId, username: username }, '注册成功');
  } catch (e) {
    if (e && e.code === 'ER_DUP_ENTRY') return fail(res, 400, '用户名或手机号已存在');
    console.error(e);
    fail(res, 500, '注册失败');
  }
});

module.exports = router;
