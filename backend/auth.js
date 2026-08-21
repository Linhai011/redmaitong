/**
 * JWT 鉴权：签发 / 校验 token + 中间件
 * 说明：
 *   - 登录成功签发一个 JWT（payload 里放 userId / role / orgId），有效期 7 天。
 *   - 前端把 token 存 localStorage，每次请求带 `Authorization: Bearer <token>`。
 *   - 中间件分三档：
 *       optionalAuth —— 有 token 就识别身份，没有也放行（浏览类读接口）
 *       requireAuth  —— 必须登录，否则 401
 *       requireRole  —— 必须登录且角色在白名单里，否则 403
 */
const jwt = require('jsonwebtoken');

const SECRET = process.env.JWT_SECRET || 'redmaitong-dev-secret-change-me';

// 签发 token（user 为 sys_user 表查出来的行）
function signToken(user) {
  return jwt.sign(
    { userId: user.user_id, role: user.role, orgId: user.org_id },
    SECRET,
    { expiresIn: '7d' }
  );
}

// 从请求头解析并校验 token；无效返回 null
function verifyToken(req) {
  var h = req.headers.authorization || '';
  var parts = h.split(' ');
  var token = (parts.length === 2 && parts[0] === 'Bearer') ? parts[1] : null;
  if (!token) return null;
  try { return jwt.verify(token, SECRET); } catch (e) { return null; }
}

// 可选鉴权
function optionalAuth(req, res, next) {
  var payload = verifyToken(req);
  if (payload) req.user = payload;
  next();
}

// 必须登录
function requireAuth(req, res, next) {
  var payload = verifyToken(req);
  if (!payload) {
    return res.status(401).json({ code: 401, msg: '未登录或登录已过期', data: null, timestamp: Date.now() });
  }
  req.user = payload;
  next();
}

// 必须满足指定角色（rest 参数收集角色白名单）
function requireRole(...roles) {
  return function (req, res, next) {
    if (!req.user) {
      return res.status(401).json({ code: 401, msg: '未登录', data: null, timestamp: Date.now() });
    }
    if (roles.indexOf(req.user.role) === -1) {
      return res.status(403).json({ code: 403, msg: '无权限执行此操作', data: null, timestamp: Date.now() });
    }
    next();
  };
}

module.exports = { signToken, verifyToken, optionalAuth, requireAuth, requireRole };
