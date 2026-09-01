/**
 * 前端动态渲染层
 * 作用：把 index.html 里写死的 mock 数据，换成从后端 API 拉真实数据渲染。
 * 降级策略：每个渲染函数 fetch 失败时【保留原有静态内容】，只弹一个提示，
 *           这样即使后端没启动，原型仍能当静态演示看。
 */

var currentResourceId = null; // 详情页当前查看的资源 id
var currentKeyword = '';      // 检索关键词
var currentPage = 1;          // 资源库当前页

// ===== 通用小工具 =====
function orgTypeName(code) {
  return ({ ARCH: '档案机构', MEM: '文博场馆', HIST: '党史研究', MARX: '高校教研', CULT: '文旅基地' })[code] || code;
}
function roleName(code) {
  return ({ PLATFORM_ADMIN: '平台管理员', ORG_ADMIN: '机构管理员', ORG_USER: '机构普通用户', INDIVIDUAL: '个人用户' })[code] || code;
}
function authStatusName(s) {
  return ({ 0: '待审批', 1: '已通过', 2: '已驳回', 3: '已过期' })[s] || '未知';
}
function shareLevelClass(level) {
  return level === 1 ? 'share-level-public' : 'share-level-auth';
}
function formatDate(d) {
  return d ? String(d).slice(0, 10) : '';
}
function offlineToast() {
  showToast('后端未连接，当前为静态演示模式', 'error');
}

// 生成资源卡片 HTML（与 index.html 里 .res-card 结构一致）
function resourceCardHTML(r) {
  var cover = r.coverUrl ? 'background-image:url(' + escapeHtml(r.coverUrl) + ');' : '';
  var fav = isLoggedIn
    ? '<span style="cursor:pointer;color:#B21018;margin-left:8px;" onclick="event.stopPropagation();toggleFavorite(' + r.resourceId + ', this)">♡</span>'
    : '';
  return '<div class="res-card" onclick="openResourceDetail(' + r.resourceId + ')">' +
    '<div class="res-img" style="' + cover + '"></div>' +
    '<div class="res-info">' +
      '<div class="res-tag-group">' +
        '<span class="tag-org">' + escapeHtml(r.orgName || '') + '</span>' +
        '<span class="tag-type">' + escapeHtml(r.subCategory || r.resTypeName || '') + '</span>' +
      '</div>' +
      '<h4 class="res-title">' + escapeHtml(r.title) + '</h4>' +
      '<p class="res-desc">' + escapeHtml(r.metaDesc || '') + '</p>' +
      '<div class="res-footer">' +
        '<span>👁️ ' + (r.viewCount || 0) + '次</span>' +
        '<span class="' + shareLevelClass(r.shareLevel) + '">' + escapeHtml(r.shareLevelName || '') + '</span>' +
        fav +
      '</div>' +
    '</div>' +
  '</div>';
}

// 生成机构卡片 HTML
function orgCardHTML(o) {
  var avatar = (o.orgName || '机').charAt(0);
  return '<div class="org-card"><div class="org-avatar">' + escapeHtml(avatar) + '</div>' +
    '<div class="org-name">' + escapeHtml(o.orgName) + '</div>' +
    '<div class="org-type">' + escapeHtml(orgTypeName(o.orgType)) + '</div>' +
    '<div class="org-res-num">' + (o.resourceCount || 0) + '<span>份资源</span></div></div>';
}

// ===== 首页 =====
async function renderHome() {
  // 入驻机构
  try {
    var orgData = await apiGet('/org/list?size=10');
    var wrap = document.getElementById('homeOrgWrap');
    if (wrap) wrap.innerHTML = orgData.list.map(orgCardHTML).join('');
  } catch (e) { offlineToast(); }

  // 热门资源（浏览数最高的前 4）
  try {
    var resData = await apiGet('/resource/search?size=4');
    var grid = document.getElementById('homeHotRes');
    if (grid) grid.innerHTML = resData.list.map(resourceCardHTML).join('');
  } catch (e) { offlineToast(); }

  // 数据统计块
  try {
    var stats = await apiGet('/stats/platform');
    var t = stats.totals;
    var nums = document.querySelectorAll('#home .data-num');
    if (nums.length >= 4) {
      nums[0].textContent = t.totalOrgs || 0;
      nums[1].textContent = (t.totalResources || 0).toLocaleString();
      nums[2].textContent = t.totalExhibitions || 0;
      nums[3].textContent = (t.totalViews || 0).toLocaleString();
    }
  } catch (e) { offlineToast(); }
}

// ===== 全域资源库 =====
async function renderResourceList() {
  var grid = document.getElementById('resourceAllGrid');
  if (!grid) return;

  var params = 'size=20&page=' + currentPage;
  if (currentKeyword) params += '&keyword=' + encodeURIComponent(currentKeyword);
  var orgVal = document.getElementById('filterOrg') ? document.getElementById('filterOrg').value : '';
  var typeVal = document.getElementById('filterType') ? document.getElementById('filterType').value : '';
  var shareVal = document.getElementById('filterShare') ? document.getElementById('filterShare').value : '';
  if (orgVal) params += '&orgId=' + orgVal;
  if (typeVal) params += '&resType=' + typeVal;
  if (shareVal) params += '&shareLevel=' + shareVal;

  try {
    var data = await apiGet('/resource/search?' + params);
    grid.innerHTML = data.list.length
      ? data.list.map(resourceCardHTML).join('')
      : '<p style="color:var(--text-light)">没有匹配的资源</p>';
    renderPagination(data.total, data.page, data.size);
  } catch (e) { offlineToast(); }
}

function renderPagination(total, page, size) {
  var box = document.getElementById('paginationBox');
  if (!box) return;
  var pages = Math.max(1, Math.ceil(total / size));
  var html = '<button class="page-btn" ' + (page <= 1 ? 'disabled' : '') + ' onclick="goPage(' + (page - 1) + ')">上一页</button>';
  var maxShow = Math.min(pages, 5);
  for (var i = 1; i <= maxShow; i++) {
    html += '<button class="page-btn ' + (i === page ? 'active' : '') + '" onclick="goPage(' + i + ')">' + i + '</button>';
  }
  html += '<button class="page-btn" ' + (page >= pages ? 'disabled' : '') + ' onclick="goPage(' + (page + 1) + ')">下一页</button>';
  box.innerHTML = html;
}
function goPage(p) { currentPage = p; renderResourceList(); }

// ===== 机构协同中心 =====
async function renderOrgTable() {
  var tbody = document.getElementById('orgTableBody');
  if (!tbody) return;
  try {
    var data = await apiGet('/org/list?size=100');
    tbody.innerHTML = data.list.map(function (o) {
      var status = o.status === 1
        ? '<span class="status-badge status-approved">已认证入驻</span>'
        : (o.status === 0 ? '<span class="status-badge status-pending">待管理员审核</span>' : '<span class="status-badge">已禁用</span>');
      var orgCode = 'ORG' + String(o.orgId).padStart(3, '0');
      return '<tr><td>' + orgCode + '</td>' +
        '<td><strong>' + escapeHtml(o.orgName) + '</strong></td>' +
        '<td><span class="badge-blue">' + escapeHtml(orgTypeName(o.orgType)) + '</span></td>' +
        '<td>' + status + '</td>' +
        '<td>' + (o.resourceCount || 0) + '</td>' +
        '<td>—</td>' +
        '<td><button class="btn-table btn-primary-sm">查看详情</button></td></tr>';
    }).join('');
  } catch (e) { offlineToast(); }
}

// ===== 共享授权 =====
async function renderShareAuthList() {
  var tbody = document.getElementById('shareAuthTableBody');
  if (!tbody) return;
  try {
    var data = await apiGet('/share/auth/list?type=received');
    var activeTab = document.querySelector('#shareAuth .tab-item.active');
    var isHandled = activeTab && activeTab.textContent.indexOf('已处理') >= 0;
    var list = data.list.filter(function (s) { return isHandled ? s.auditStatus !== 0 : s.auditStatus === 0; });

    if (list.length === 0) { tbody.innerHTML = '<tr><td colspan="6" style="text-align:center;color:var(--text-light)">暂无数据</td></tr>'; return; }
    tbody.innerHTML = list.map(function (s) {
      var authCode = 'AUTH' + String(s.authId).padStart(10, '0');
      var badge = s.auditStatus === 0 ? 'status-pending' : (s.auditStatus === 1 ? 'status-approved' : 'status-pending');
      var action = s.auditStatus === 0
        ? '<button class="btn-table btn-success-sm" onclick="auditShareAuth(' + s.authId + ', 1)">通过</button>' +
          '<button class="btn-table btn-danger-sm" onclick="auditShareAuth(' + s.authId + ', 2)">驳回</button>'
        : '<button class="btn-table btn-secondary-sm">查看记录</button>';
      return '<tr><td>' + authCode + '</td>' +
        '<td><strong>' + escapeHtml(s.applyOrgName) + '</strong></td>' +
        '<td>' + escapeHtml(s.resourceTitle) + '</td>' +
        '<td>' + escapeHtml(s.applyPurpose || '') + '</td>' +
        '<td><span class="status-badge ' + badge + '">' + authStatusName(s.auditStatus) + '</span></td>' +
        '<td>' + action + '</td></tr>';
    }).join('');
  } catch (e) { showToast(e.message, 'error'); }
}

async function auditShareAuth(authId, result) {
  try {
    await apiPut('/share/auth/audit', { authId: authId, auditResult: result });
    showToast(result === 1 ? '已通过' : '已驳回', 'success');
    renderShareAuthList();
  } catch (e) { showToast(e.message, 'error'); }
}

// ===== 联合展馆 =====
async function renderExhibitions() {
  var grid = document.getElementById('exhibitionGrid');
  if (!grid) return;
  try {
    var data = await apiGet('/exhibition/list');
    grid.innerHTML = data.list.map(function (ex) {
      return '<div class="exhibition-card"><div class="exhibition-img"></div><div class="exhibition-info">' +
        '<div class="res-tag-group"><span class="tag-org">' + (ex.orgCount || 0) + '家机构联合</span></div>' +
        '<h4 class="res-title">' + escapeHtml(ex.exhibitionName) + '</h4>' +
        '<p class="res-desc">' + escapeHtml(ex.description || '') + '</p></div></div>';
    }).join('');
  } catch (e) { offlineToast(); }
}

// ===== 资源详情 =====
function openResourceDetail(id) {
  currentResourceId = id;
  switchPage('resourceDetail');
  if (isLoggedIn) {
    apiPost('/browse/' + id).catch(function () {}); // 记录浏览（失败不影响展示）
  }
}

async function renderResourceDetail(id) {
  try {
    var d = await apiGet('/resource/' + id);
    var title = document.getElementById('detailTitle');
    if (title) title.textContent = d.title;
    var meta = document.getElementById('detailMeta');
    if (meta) {
      meta.innerHTML = '<span>' + escapeHtml(d.subCategory || '') + '</span>' +
        '<span>' + escapeHtml(d.orgName || '') + '提供</span>' +
        '<span>' + escapeHtml(d.resourceYear || '') + '</span>' +
        '<span>共享等级：' + escapeHtml(d.shareLevelName || '') + '</span>';
    }
    var desc = document.getElementById('detailDesc');
    if (desc) desc.innerHTML = '<p>' + escapeHtml(d.metaDesc || '') + '</p>';
    var views = document.getElementById('detailViews');
    if (views) views.textContent = d.viewCount || 0;
    var downloads = document.getElementById('detailDownloads');
    if (downloads) downloads.textContent = d.downloadCount || 0;
    var created = document.getElementById('detailCreated');
    if (created) created.textContent = formatDate(d.createdAt);
    var applyName = document.getElementById('applyResName');
    if (applyName) applyName.value = d.title;
  } catch (e) { showToast(e.message, 'error'); }
}

// ===== 数据统计仪表盘 =====
var _dashCharts = {};
async function renderDashboard() {
  try {
    var stats = await apiGet('/stats/platform');
    fillKPI(stats.totals);
    fillTop5(stats.orgRank);
    drawDashboardCharts(stats);
  } catch (e) { offlineToast(); }
}

function fillKPI(t) {
  var nums = document.querySelectorAll('#dashboard .dash-num');
  if (nums.length >= 4) {
    nums[0].textContent = t.totalOrgs || 0;
    nums[1].textContent = (t.totalResources || 0).toLocaleString();
    nums[2].textContent = (t.totalViews || 0).toLocaleString();
    nums[3].textContent = (t.totalDownloads || 0).toLocaleString();
  }
}

function fillTop5(orgRank) {
  var tbody = document.getElementById('top5Body');
  if (!tbody) return;
  var badges = ['badge-red', 'badge-blue', 'badge-green'];
  tbody.innerHTML = (orgRank || []).map(function (o, i) {
    var rank = i < 3 ? '<span class="' + badges[i] + '">' + (i + 1) + '</span>' : (i + 1);
    return '<tr><td>' + rank + '</td>' +
      '<td><strong>' + escapeHtml(o.orgName) + '</strong></td>' +
      '<td>' + (o.resourceCount || 0) + '</td>' +
      '<td>' + (o.level1 || 0) + '</td>' +
      '<td>' + (o.level2 || 0) + '</td></tr>';
  }).join('');
}

function drawDashboardCharts(stats) {
  if (typeof echarts === 'undefined') return;
  var colors = ['#B21018', '#D4AF37', '#059669', '#3B82F6', '#8B5CF6', '#D97706'];

  var pieDom = document.getElementById('chartPie');
  if (pieDom) {
    var pie = _dashCharts.pie || echarts.init(pieDom);
    _dashCharts.pie = pie;
    pie.setOption({
      tooltip: { trigger: 'item' }, legend: { bottom: 0, textStyle: { fontSize: 12 } },
      series: [{
        type: 'pie', radius: ['50%', '75%'], center: ['50%', '45%'],
        label: { formatter: '{b}\n{d}%' },
        data: (stats.resTypeDist || []).map(function (d, i) { return { value: d.value, name: d.name, itemStyle: { color: colors[i % colors.length] } }; })
      }]
    });
  }

  var lineDom = document.getElementById('chartLine');
  if (lineDom) {
    var line = _dashCharts.line || echarts.init(lineDom);
    _dashCharts.line = line;
    var trend = stats.monthlyTrend || [];
    line.setOption({
      tooltip: { trigger: 'axis' }, legend: { data: ['资源上传量', '共享申请量'], bottom: 0 },
      grid: { left: '3%', right: '4%', bottom: '12%', containLabel: true },
      xAxis: { type: 'category', data: trend.map(function (m) { return m.month; }) },
      yAxis: { type: 'value' },
      series: [
        { name: '资源上传量', type: 'line', smooth: true, data: trend.map(function (m) { return m.uploadCount; }), lineStyle: { color: '#B21018' }, itemStyle: { color: '#B21018' } },
        { name: '共享申请量', type: 'line', smooth: true, data: trend.map(function (m) { return m.shareCount; }), lineStyle: { color: '#D4AF37' }, itemStyle: { color: '#D4AF37' } }
      ]
    });
  }

  var barDom = document.getElementById('chartBar');
  if (barDom) {
    var bar = _dashCharts.bar || echarts.init(barDom);
    _dashCharts.bar = bar;
    var rank = stats.orgRank || [];
    bar.setOption({
      tooltip: { trigger: 'axis' }, grid: { left: '3%', right: '4%', bottom: '3%', containLabel: true },
      xAxis: { type: 'value' }, yAxis: { type: 'category', data: rank.map(function (o) { return o.orgName; }) },
      series: [{
        type: 'bar', data: rank.map(function (o) { return o.resourceCount; }),
        itemStyle: { color: new echarts.graphic.LinearGradient(0, 0, 1, 0, [{ offset: 0, color: '#B21018' }, { offset: 1, color: '#D4AF37' }]) },
        label: { show: true, position: 'right' }
      }]
    });
  }

  if (!_dashCharts._resizeBound) {
    _dashCharts._resizeBound = true;
    window.addEventListener('resize', function () {
      Object.keys(_dashCharts).forEach(function (k) { if (_dashCharts[k] && _dashCharts[k].resize) _dashCharts[k].resize(); });
    });
  }
}

// ===== 个人中心 =====
async function renderUserCenter() {
  // 填充用户信息（登录后才有）
  var u = getUser();
  if (u) {
    var nameEl = document.getElementById('profileName');
    if (nameEl) nameEl.textContent = u.username;
    var orgEl = document.getElementById('profileOrg');
    if (orgEl) orgEl.textContent = (u.orgName ? '🏛️ ' + u.orgName + ' · ' : '') + roleName(u.role);
    var avatarBtn = document.getElementById('userAvatarBtn');
    if (avatarBtn) avatarBtn.textContent = (u.username || '用').charAt(0);
  }

  var activeTab = document.querySelector('#userCenter .tab-item.active');
  var tab = activeTab ? activeTab.textContent.trim() : '我的收藏';
  var grid = document.getElementById('collectionGrid');
  if (!grid) return;
  if (tab.indexOf('下载') >= 0) renderDownloadList(grid);
  else if (tab.indexOf('浏览') >= 0) renderHistoryList(grid);
  else renderFavoriteList(grid);
}

async function renderFavoriteList(grid) {
  try {
    var data = await apiGet('/favorite/list');
    if (!data.list.length) { grid.innerHTML = '<p style="color:var(--text-light)">暂无收藏</p>'; return; }
    grid.innerHTML = data.list.map(function (f) {
      var cover = f.coverUrl ? 'background-image:url(' + escapeHtml(f.coverUrl) + ');' : '';
      return '<div class="res-card" onclick="openResourceDetail(' + f.resourceId + ')">' +
        '<div class="res-img" style="' + cover + '"></div><div class="res-info">' +
        '<div class="res-tag-group"><span class="tag-org">' + escapeHtml(f.orgName || '') + '</span>' +
        '<span class="tag-type">' + escapeHtml(f.subCategory || '') + '</span></div>' +
        '<h4 class="res-title">' + escapeHtml(f.title) + '</h4>' +
        '<div class="res-footer"><span>收藏于 ' + formatDate(f.favoritedAt) + '</span><span>👁️ ' + (f.viewCount || 0) + '</span>' +
        '<button class="btn-table btn-secondary-sm" style="margin-left:8px;" onclick="event.stopPropagation();unfavorite(' + f.resourceId + ')">取消收藏</button></div>' +
        '</div></div>';
    }).join('');
  } catch (e) { showToast(e.message, 'error'); }
}

async function renderDownloadList(grid) {
  try {
    var data = await apiGet('/download/list');
    if (!data.list.length) { grid.innerHTML = '<p style="color:var(--text-light)">暂无下载记录</p>'; return; }
    grid.innerHTML = data.list.map(function (d) {
      return '<div class="res-card"><div class="res-info">' +
        '<h4 class="res-title">' + escapeHtml(d.title) + '</h4>' +
        '<div class="res-footer"><span>' + escapeHtml(d.orgName || '') + '</span><span>下载于 ' + formatDate(d.createdAt) + '</span></div>' +
        '</div></div>';
    }).join('');
  } catch (e) { showToast(e.message, 'error'); }
}

async function renderHistoryList(grid) {
  try {
    var data = await apiGet('/history/list');
    if (!data.list.length) { grid.innerHTML = '<p style="color:var(--text-light)">暂无浏览历史</p>'; return; }
    grid.innerHTML = data.list.map(function (h) {
      return '<div class="res-card" onclick="openResourceDetail(' + h.resourceId + ')"><div class="res-info">' +
        '<h4 class="res-title">' + escapeHtml(h.title) + '</h4>' +
        '<div class="res-footer"><span>' + escapeHtml(h.orgName || '') + '</span><span>浏览于 ' + formatDate(h.createdAt) + '</span></div>' +
        '</div></div>';
    }).join('');
  } catch (e) { showToast(e.message, 'error'); }
}

// ===== 收藏/取消收藏 =====
async function toggleFavorite(id, el) {
  if (!isLoggedIn) { showToast('请先登录', 'error'); switchPage('userLogin'); return; }
  try {
    await apiPost('/favorite/' + id);
    showToast('已收藏', 'success');
    if (el) el.textContent = '♥';
  } catch (e) { showToast(e.message, 'error'); }
}

async function unfavorite(id) {
  try {
    await apiDelete('/favorite/' + id);
    showToast('已取消收藏', 'success');
    renderUserCenter();
  } catch (e) { showToast(e.message, 'error'); }
}

// ===== 筛选下拉初始化 =====
async function initFilters() {
  var typeSelect = document.getElementById('filterType');
  if (typeSelect) {
    typeSelect.innerHTML = '<option value="">全部类型</option>' +
      '<option value="1">党史文献档案</option><option value="2">革命文物3D/图像</option>' +
      '<option value="3">红色影像视频</option><option value="4">口述历史音频</option>' +
      '<option value="5">红色教研素材</option><option value="6">旧址全景VR</option>';
  }
  var shareSelect = document.getElementById('filterShare');
  if (shareSelect) {
    shareSelect.innerHTML = '<option value="">全部共享等级</option>' +
      '<option value="1">完全公开</option><option value="2">授权访问</option><option value="3">机构内部</option>';
  }
  var orgSelect = document.getElementById('filterOrg');
  if (orgSelect) {
    try {
      var data = await apiGet('/org/list?size=100');
      var html = '<option value="">全部协同机构</option>';
      data.list.forEach(function (o) { html += '<option value="' + o.orgId + '">' + escapeHtml(o.orgName) + '</option>'; });
      orgSelect.innerHTML = html;
    } catch (e) {}
  }
}
