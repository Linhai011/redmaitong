/**
 * 工具：字段名映射 + 统一响应包
 * 作用：
 *   - DB 是 snake_case（org_id / view_count），接口契约要求 camelCase（orgId / viewCount），
 *     这里统一把查询结果的行键名转成 camelCase 再返回给前端。
 *   - 所有接口返回统一结构 { code, msg, data, timestamp }（对齐 API接口设计文档.md）。
 */

// snake_case → camelCase（org_id → orgId，resource_count → resourceCount）
function camelize(str) {
  return String(str).replace(/_([a-z0-9])/g, function (m, c) { return c.toUpperCase(); });
}

// 单行记录：键名转 camelCase
function toCamel(row) {
  if (!row || typeof row !== 'object') return row;
  var out = {};
  for (var k in row) {
    if (Object.prototype.hasOwnProperty.call(row, k)) out[camelize(k)] = row[k];
  }
  return out;
}

// 多行记录：逐行转
function toCamelList(rows) {
  return (rows || []).map(toCamel);
}

// 共享等级 1/2/3 → 中文名（供后端直接返回 shareLevelName）
function shareLevelName(level) {
  return ({ 1: '完全公开', 2: '授权访问', 3: '机构内部' })[level] || '未知';
}

// 成功响应包
function ok(res, data, msg) {
  res.json({ code: 200, msg: msg || 'ok', data: data === undefined ? null : data, timestamp: Date.now() });
}

// 失败响应包（code 同时作为 HTTP 状态码与响应体里的业务码）
function fail(res, code, msg) {
  res.status(code).json({ code: code, msg: msg || 'error', data: null, timestamp: Date.now() });
}

module.exports = { camelize, toCamel, toCamelList, shareLevelName, ok, fail };
