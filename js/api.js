/**
 * 前端 API 封装
 * 作用：把对后端的 fetch 请求统一处理——
 *   - 自动带上 Authorization: Bearer <token>
 *   - 解包 { code, msg, data }，非 200 直接抛出错误
 * 其它脚本统一用这里的 apiGet / apiPost / apiPut / apiDelete，不要直接写 fetch。
 */

// 后端基地址。同源托管（浏览器访问 http://VM_IP:3000）时用相对路径即可。
// 若用 file:// 双击打开 index.html，则要改成后端的绝对地址（见下一行）。
var API_BASE = '/v1';
if (location.protocol === 'file:') {
  API_BASE = 'http://localhost:3000/v1'; // 改成你 VM 的 IP，例如 http://192.168.1.100:3000/v1
}

var TOKEN_KEY = 'redmaitong_token';
var USER_KEY = 'redmaitong_user';

function getToken() { return localStorage.getItem(TOKEN_KEY); }
function setToken(t) { localStorage.setItem(TOKEN_KEY, t); }
function getUser() { try { return JSON.parse(localStorage.getItem(USER_KEY)); } catch (e) { return null; } }
function setUser(u) { localStorage.setItem(USER_KEY, JSON.stringify(u)); }
function clearAuth() { localStorage.removeItem(TOKEN_KEY); localStorage.removeItem(USER_KEY); }

// 核心请求函数
async function request(method, path, body) {
  var headers = {};
  var token = getToken();
  if (token) headers['Authorization'] = 'Bearer ' + token;

  var options = { method: method, headers: headers };
  if (typeof FormData !== 'undefined' && body instanceof FormData) {
    options.body = body; // FormData 不手动设 Content-Type，浏览器会自动带 boundary
  } else if (body !== undefined && body !== null) {
    headers['Content-Type'] = 'application/json';
    options.body = JSON.stringify(body);
  }

  var resp = await fetch(API_BASE + path, options);
  var data = await resp.json().catch(function () {
    return { code: resp.status, msg: '响应解析失败', data: null };
  });
  if (data.code !== 200) {
    var err = new Error(data.msg || '请求失败');
    err.code = data.code;
    throw err;
  }
  return data.data;
}

function apiGet(path) { return request('GET', path); }
function apiPost(path, body) { return request('POST', path, body); }
function apiPut(path, body) { return request('PUT', path, body); }
function apiDelete(path) { return request('DELETE', path); }
