/**
 * 红脉通 - 红色数字资源协同共享平台 主脚本 v3（已接入后端）
 */

// ===================== XSS 防护 =====================
function escapeHtml(str) {
  var div = document.createElement('div');
  div.appendChild(document.createTextNode(str));
  return div.innerHTML;
}

// ===================== Toast 通知 =====================
function showToast(msg, type) {
  type = type || 'info';
  var container = document.getElementById('toastContainer');
  var toast = document.createElement('div');
  toast.className = 'toast ' + type;
  toast.textContent = msg;
  container.appendChild(toast);
  setTimeout(function () { toast.remove(); }, 3000);
}

// ===================== 登录状态管理 =====================
// 从 localStorage 恢复登录态（token 存在即视为已登录）
var isLoggedIn = !!getToken();
var currentUser = getUser() || { name: '', role: '', org: '' };

async function doLogin() {
  var username = document.getElementById('loginUsername').value.trim();
  var password = document.getElementById('loginPassword').value;
  try {
    var data = await apiPost('/auth/login', { username: username, password: password });
    setToken(data.token);
    setUser(data);
    isLoggedIn = true;
    currentUser = { name: data.username, role: roleName(data.role), org: data.orgName || '' };
    applyLoggedInUI();
    showToast('登录成功！欢迎回来，' + data.username, 'success');
    switchPage('home');
  } catch (e) {
    showToast(e.message || '登录失败', 'error');
  }
}

function applyLoggedInUI() {
  document.getElementById('btnOrgEntry').style.display = 'none';
  document.getElementById('btnLogin').style.display = 'none';
  document.getElementById('userDropdown').classList.add('visible');
  var avatar = document.getElementById('userAvatarBtn');
  if (avatar) avatar.textContent = (currentUser.name || '用').charAt(0);
}

function doLogout() {
  clearAuth();
  isLoggedIn = false;
  currentUser = { name: '', role: '', org: '' };
  document.getElementById('btnOrgEntry').style.display = '';
  document.getElementById('btnLogin').style.display = '';
  document.getElementById('userDropdown').classList.remove('visible');
  document.getElementById('userDropdownMenu').classList.remove('active');
  showToast('已安全退出', 'info');
  switchPage('home');
}

function toggleUserMenu(e) {
  e.stopPropagation();
  var menu = document.getElementById('userDropdownMenu');
  menu.classList.toggle('active');
}

// ===================== 页面路由 =====================
var pageBreadcrumbMap = {
  home:            ['首页'],
  resourceAll:     ['首页', '全域资源库'],
  orgManage:       ['首页', '机构协同中心'],
  resourceUpload:  ['首页', '机构资源上传'],
  shareAuth:       ['首页', '共享权限管理'],
  exhibitionJoint: ['首页', '联合专题展馆'],
  dashboard:       ['首页', '数据统计'],
  resourceDetail:  ['首页', '全域资源库', '资源详情'],
  userLogin:       ['首页', '用户登录'],
  orgRegister:     ['首页', '机构入驻'],
  apiDoc:          ['首页', 'API接口文档'],
  userCenter:      ['首页', '个人中心']
};

function switchPage(pageId) {
  // 如果没登录且访问个人中心，跳转登录
  if (pageId === 'userCenter' && !isLoggedIn) {
    showToast('请先登录', 'error');
    switchPage('userLogin');
    return;
  }

  var pages = document.querySelectorAll('.page');
  for (var i = 0; i < pages.length; i++) { pages[i].classList.remove('active'); }
  var target = document.getElementById(pageId);
  if (target) target.classList.add('active');

  // 更新导航高亮
  var navLinks = document.querySelectorAll('.nav-main li a');
  for (var j = 0; j < navLinks.length; j++) { navLinks[j].classList.remove('active'); }
  var activeLink = document.querySelector('.nav-main li a[data-page="' + pageId + '"]');
  if (activeLink) activeLink.classList.add('active');

  // 更新面包屑
  renderBreadcrumb(pageId);

  // 进入页面时触发对应的动态渲染（函数在 render.js）
  var pageRenderMap = {
    home: renderHome,
    resourceAll: renderResourceList,
    orgManage: renderOrgTable,
    shareAuth: renderShareAuthList,
    exhibitionJoint: renderExhibitions,
    dashboard: renderDashboard,
    resourceDetail: function () { if (currentResourceId) renderResourceDetail(currentResourceId); },
    userCenter: renderUserCenter
  };
  if (pageRenderMap[pageId]) { pageRenderMap[pageId](); }

  closeMobileMenu();
  window.scrollTo(0, 0);
}

function renderBreadcrumb(pageId) {
  var bc = document.getElementById('breadcrumb');
  var items = pageBreadcrumbMap[pageId];
  if (!items || items.length <= 1) { bc.style.display = 'none'; return; }
  bc.style.display = 'flex';
  var html = '';
  for (var i = 0; i < items.length; i++) {
    if (i > 0) html += '<span class="sep">/</span>';
    if (i === items.length - 1) {
      html += '<span class="current">' + items[i] + '</span>';
    } else {
      html += '<a href="#" data-nav="' + (i === 0 ? 'home' : 'resourceAll') + '">' + items[i] + '</a>';
    }
  }
  bc.innerHTML = html;
}

// ===================== Tab 切换 =====================
function switchTab(tab) {
  var tabs = tab.parentElement.querySelectorAll('.tab-item');
  for (var i = 0; i < tabs.length; i++) { tabs[i].classList.remove('active'); }
  tab.classList.add('active');
  showToast('已切换到「' + tab.textContent.trim() + '」', 'info');

  // 切换子 tab 时重新拉对应列表
  if (tab.closest('#shareAuth')) { renderShareAuthList(); }
  if (tab.closest('#userCenter')) { renderUserCenter(); }
}

// ===================== 弹窗 =====================
function openApplyModal() {
  document.getElementById('applyModal').classList.add('active');
}
function closeApplyModal() {
  document.getElementById('applyModal').classList.remove('active');
}
function openPreviewModal() {
  document.getElementById('previewModal').classList.add('active');
}
function closePreviewModal() {
  document.getElementById('previewModal').classList.remove('active');
}

// ===================== 搜索功能 =====================
function doSearch() {
  var input = document.getElementById('bannerSearchInput');
  var keyword = input ? input.value.trim() : '';
  if (!keyword) { showToast('请输入检索关键词', 'error'); return; }
  currentKeyword = keyword;
  currentPage = 1;
  switchPage('resourceAll');
  if (input) input.value = '';
}

function handleSearchKey(e) { if (e.key === 'Enter') doSearch(); }

function filterResources() {
  currentPage = 1;
  renderResourceList();
}

function clearFilter() {
  var selects = document.querySelectorAll('#resourceAll select');
  for (var i = 0; i < selects.length; i++) { selects[i].selectedIndex = 0; }
  currentKeyword = '';
  currentPage = 1;
  renderResourceList();
  showToast('筛选已清除', 'info');
}

// ===================== 表单验证 =====================
function validateForm(form) {
  var inputs = form.querySelectorAll('input[required], select[required], textarea[required]');
  var valid = true, firstError = null;
  var errors = form.querySelectorAll('.error');
  for (var i = 0; i < errors.length; i++) { errors[i].classList.remove('error'); }

  for (var j = 0; j < inputs.length; j++) {
    var el = inputs[j], val = el.value.trim();
    if (!val) { el.classList.add('error'); if (!firstError) firstError = el; valid = false; continue; }
    if (el.type === 'tel' || el.getAttribute('data-type') === 'phone') {
      if (!/^1[3-9]\d{9}$/.test(val)) { el.classList.add('error'); if (!firstError) firstError = el; valid = false; }
    }
    if (el.getAttribute('data-type') === 'creditCode') {
      if (val.length !== 18) { el.classList.add('error'); if (!firstError) firstError = el; valid = false; }
    }
  }
  if (firstError) firstError.focus();
  return valid;
}

function handleOrgRegister(e) {
  e.preventDefault();
  var f = document.getElementById('orgRegisterForm');
  if (!validateForm(f)) { showToast('请完善必填信息后再提交', 'error'); return; }
  var body = {
    orgName: document.getElementById('orgName').value.trim(),
    orgType: document.getElementById('orgType').value,
    creditCode: document.getElementById('creditCode').value.trim(),
    orgAddress: document.getElementById('orgAddress').value.trim(),
    contactName: document.getElementById('contactName').value.trim(),
    contactPhone: document.getElementById('contactPhone').value.trim(),
    orgDesc: document.getElementById('orgDesc').value.trim(),
    applyReason: document.getElementById('applyReason').value.trim()
  };
  apiPost('/org/apply', body)
    .then(function () { showToast('入驻申请已提交，等待平台审核', 'success'); f.reset(); })
    .catch(function (err) { showToast(err.message, 'error'); });
}
function handleResourceUpload(e) {
  e.preventDefault();
  var f = document.getElementById('resourceUploadForm');
  if (!validateForm(f)) { showToast('请完善必填信息后再提交', 'error'); return; }
  var cb = document.getElementById('authCheck');
  if (cb && !cb.checked) { showToast('请先同意版权共享授权协议', 'error'); return; }
  if (!isLoggedIn) { showToast('请先登录机构账号', 'error'); switchPage('userLogin'); return; }

  var fd = new FormData();
  fd.append('title', document.getElementById('resTitle').value.trim());
  fd.append('resType', document.getElementById('resType').value);
  fd.append('metaDesc', document.getElementById('resDesc').value.trim());
  fd.append('resourceYear', document.getElementById('resYear').value.trim());
  fd.append('shareLevel', document.getElementById('resShareLevel').value);
  var fileInput = document.getElementById('resFile');
  for (var i = 0; i < fileInput.files.length; i++) { fd.append('file', fileInput.files[i]); }

  apiPost('/resource/upload', fd)
    .then(function () { showToast('资源已提交上传，同步至全域资源池', 'success'); f.reset(); })
    .catch(function (err) { showToast(err.message, 'error'); });
}
function handleLogin(e) {
  e.preventDefault();
  var f = document.getElementById('loginForm');
  if (!validateForm(f)) { showToast('请填写完整登录信息', 'error'); return; }
  doLogin();
}
function handleApplySubmit(e) {
  e.preventDefault();
  var f = document.getElementById('applyForm');
  if (!validateForm(f)) { showToast('请完善申请信息', 'error'); return; }
  if (!isLoggedIn) { showToast('请先登录', 'error'); closeApplyModal(); switchPage('userLogin'); return; }
  var body = {
    resourceId: currentResourceId,
    applyPurpose: document.getElementById('applyPurpose').value.trim(),
    useDuration: document.getElementById('applyDuration').value,
    contactPerson: document.getElementById('applyContact').value.trim(),
    contactPhone: document.getElementById('applyPhone').value.trim()
  };
  apiPost('/share/apply', body)
    .then(function () { showToast('跨机构调取申请已提交', 'success'); closeApplyModal(); })
    .catch(function (err) { showToast(err.message, 'error'); });
}

// ===================== 移动端汉堡菜单 =====================
function toggleMobileMenu() {
  var overlay = document.getElementById('mobileOverlay'), nav = document.getElementById('mobileNav');
  var hamburger = document.getElementById('hamburgerBtn');
  var isActive = nav.classList.contains('active');
  if (isActive) { nav.classList.remove('active'); overlay.classList.remove('active'); hamburger.classList.remove('active'); document.body.style.overflow = ''; }
  else { syncMobileNav(); nav.classList.add('active'); overlay.classList.add('active'); hamburger.classList.add('active'); document.body.style.overflow = 'hidden'; }
}
function closeMobileMenu() {
  var overlay = document.getElementById('mobileOverlay'), nav = document.getElementById('mobileNav');
  var hamburger = document.getElementById('hamburgerBtn');
  nav.classList.remove('active'); overlay.classList.remove('active'); hamburger.classList.remove('active');
  document.body.style.overflow = '';
}
function syncMobileNav() {
  var mobileBody = document.getElementById('mobileNavBody');
  if (mobileBody.children.length > 0) return;
  var desktopNav = document.querySelector('header .nav-main');
  if (desktopNav) {
    var navClone = desktopNav.cloneNode(true);
    var links = navClone.querySelectorAll('a');
    for (var i = 0; i < links.length; i++) { links[i].addEventListener('click', function () { setTimeout(closeMobileMenu, 150); }); }
    mobileBody.appendChild(navClone);
  }
}

// ===================== 返回顶部 =====================
function initBackToTop() {
  var btn = document.getElementById('backToTop');
  if (!btn) return;
  window.addEventListener('scroll', function () { btn.classList.toggle('visible', window.scrollY > 400); });
  btn.addEventListener('click', function () { window.scrollTo({ top: 0, behavior: 'smooth' }); });
}

// ===================== 初始化 =====================
function init() {
  // 导航链接绑定 (data-page)
  var navLinks = document.querySelectorAll('.nav-main li a[data-page]');
  for (var i = 0; i < navLinks.length; i++) {
    navLinks[i].addEventListener('click', function (e) {
      e.preventDefault();
      switchPage(this.getAttribute('data-page'));
    });
  }

  // 顶部公告「API接口文档入口」等 .js-nav-link 链接绑定
  var jsNavLinks = document.querySelectorAll('.js-nav-link');
  for (var k = 0; k < jsNavLinks.length; k++) {
    jsNavLinks[k].addEventListener('click', function (e) {
      e.preventDefault();
      switchPage(this.getAttribute('data-page'));
    });
  }

  // 面包屑点击
  document.getElementById('breadcrumb').addEventListener('click', function (e) {
    var link = e.target.closest('a[data-nav]');
    if (!link) return; e.preventDefault();
    switchPage(link.getAttribute('data-nav'));
  });

  // Banner 搜索
  var searchBtn = document.querySelector('.banner-search button');
  if (searchBtn) searchBtn.addEventListener('click', doSearch);
  var searchInput = document.getElementById('bannerSearchInput');
  if (searchInput) searchInput.addEventListener('keydown', handleSearchKey);

  // 筛选
  var filterBtn = document.querySelector('#resourceAll .btn-filter');
  if (filterBtn) filterBtn.addEventListener('click', filterResources);

  // 弹窗背景关闭
  document.getElementById('applyModal').addEventListener('click', function (e) { if (e.target === this) closeApplyModal(); });
  document.getElementById('previewModal').addEventListener('click', function (e) { if (e.target === this) closePreviewModal(); });

  // 用户下拉菜单外部点击关闭
  document.addEventListener('click', function () {
    document.getElementById('userDropdownMenu').classList.remove('active');
  });

  // 汉堡菜单
  document.getElementById('hamburgerBtn').addEventListener('click', toggleMobileMenu);
  document.getElementById('mobileOverlay').addEventListener('click', closeMobileMenu);

  // 返回顶部
  initBackToTop();

  // ESC 关闭所有弹窗和菜单
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') {
      closeApplyModal();
      closePreviewModal();
      closeMobileMenu();
      document.getElementById('userDropdownMenu').classList.remove('active');
    }
  });

  // 若已登录（刷新页面后），恢复头部登录态
  if (isLoggedIn) { applyLoggedInUI(); }

  // 初始化筛选下拉 + 首次渲染首页数据
  initFilters();
  renderHome();

  console.log('红脉通平台 v3 已初始化（已接入后端）✓');
}

document.addEventListener('DOMContentLoaded', init);
