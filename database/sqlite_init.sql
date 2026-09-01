-- ============================================================================
-- 红脉通 · SQLite 数据库初始化脚本
-- 由 MySQL 版 01_schema.sql + 02_seed.sql + 05_more_data.sql 转换而来
-- 供后端（node:sqlite）在首次启动（.db 文件不存在）时执行一次
-- 说明：外键在 db.js 里用 PRAGMA foreign_keys=ON 开启；本脚本建表+灌数据时默认关闭
-- ============================================================================

DROP TABLE IF EXISTS operation_log;
DROP TABLE IF EXISTS notification;
DROP TABLE IF EXISTS browse_history;
DROP TABLE IF EXISTS download_record;
DROP TABLE IF EXISTS favorite;
DROP TABLE IF EXISTS exhibition_resource;
DROP TABLE IF EXISTS exhibition_org;
DROP TABLE IF EXISTS exhibition;
DROP TABLE IF EXISTS share_auth;
DROP TABLE IF EXISTS resource_file;
DROP TABLE IF EXISTS resource_tag;
DROP TABLE IF EXISTS tag;
DROP TABLE IF EXISTS resource;
DROP TABLE IF EXISTS resource_category;
DROP TABLE IF EXISTS sys_user;
DROP TABLE IF EXISTS org;

-- 1. org 机构表
CREATE TABLE org (
  org_id         INTEGER PRIMARY KEY AUTOINCREMENT,
  org_name       TEXT NOT NULL,
  org_type       TEXT NOT NULL,
  credit_code    TEXT,
  address        TEXT,
  contact_name   TEXT,
  contact_phone  TEXT,
  email          TEXT,
  description    TEXT,
  apply_reason   TEXT,
  cert_file_path TEXT,
  api_level      INTEGER NOT NULL DEFAULT 1,
  status         INTEGER NOT NULL DEFAULT 0,
  created_at     TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  updated_at     TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  UNIQUE (credit_code)
);
CREATE INDEX idx_org_type ON org (org_type);
CREATE INDEX idx_org_status ON org (status);

-- 2. sys_user 用户表
CREATE TABLE sys_user (
  user_id       INTEGER PRIMARY KEY AUTOINCREMENT,
  username      TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  phone         TEXT,
  email         TEXT,
  role          TEXT NOT NULL DEFAULT 'INDIVIDUAL',
  org_id        INTEGER,
  status        INTEGER NOT NULL DEFAULT 1,
  created_at    TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  updated_at    TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  UNIQUE (username),
  UNIQUE (phone),
  FOREIGN KEY (org_id) REFERENCES org (org_id) ON DELETE SET NULL ON UPDATE CASCADE
);
CREATE INDEX idx_user_org ON sys_user (org_id);
CREATE INDEX idx_user_role ON sys_user (role);

-- 3. resource_category 资源分类目录表（自关联，两级）
CREATE TABLE resource_category (
  category_id   INTEGER PRIMARY KEY AUTOINCREMENT,
  category_name TEXT NOT NULL,
  parent_id     INTEGER,
  level         INTEGER NOT NULL,
  sort_order    INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (parent_id) REFERENCES resource_category (category_id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX idx_category_parent ON resource_category (parent_id);

-- 4. resource 资源表（核心业务表）
CREATE TABLE resource (
  resource_id    INTEGER PRIMARY KEY AUTOINCREMENT,
  title          TEXT NOT NULL,
  category_id    INTEGER NOT NULL,
  org_id         INTEGER NOT NULL,
  meta_desc      TEXT,
  resource_year  TEXT,
  share_level    INTEGER NOT NULL DEFAULT 2,
  cover_url      TEXT,
  view_count     INTEGER NOT NULL DEFAULT 0,
  download_count INTEGER NOT NULL DEFAULT 0,
  audit_status   INTEGER NOT NULL DEFAULT 0,
  created_at     TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  updated_at     TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  CHECK (share_level BETWEEN 1 AND 3),
  FOREIGN KEY (category_id) REFERENCES resource_category (category_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  FOREIGN KEY (org_id) REFERENCES org (org_id) ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX idx_resource_org ON resource (org_id);
CREATE INDEX idx_resource_category ON resource (category_id);
CREATE INDEX idx_resource_share ON resource (share_level);
CREATE INDEX idx_resource_audit ON resource (audit_status);

-- 5. tag 标签表
CREATE TABLE tag (
  tag_id   INTEGER PRIMARY KEY AUTOINCREMENT,
  tag_name TEXT NOT NULL,
  UNIQUE (tag_name)
);

-- 6. resource_tag 资源-标签关联表
CREATE TABLE resource_tag (
  resource_id INTEGER NOT NULL,
  tag_id      INTEGER NOT NULL,
  PRIMARY KEY (resource_id, tag_id),
  FOREIGN KEY (resource_id) REFERENCES resource (resource_id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (tag_id) REFERENCES tag (tag_id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX idx_rt_tag ON resource_tag (tag_id);

-- 7. resource_file 资源文件表
CREATE TABLE resource_file (
  file_id     INTEGER PRIMARY KEY AUTOINCREMENT,
  resource_id INTEGER NOT NULL,
  file_name   TEXT,
  file_path   TEXT NOT NULL,
  file_size   INTEGER,
  file_type   TEXT,
  sort_order  INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (resource_id) REFERENCES resource (resource_id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX idx_file_resource ON resource_file (resource_id);

-- 8. share_auth 共享授权申请表
CREATE TABLE share_auth (
  auth_id        INTEGER PRIMARY KEY AUTOINCREMENT,
  resource_id    INTEGER NOT NULL,
  apply_org_id   INTEGER NOT NULL,
  target_org_id  INTEGER NOT NULL,
  apply_user_id  INTEGER,
  apply_purpose  TEXT NOT NULL,
  use_duration   TEXT,
  contact_person TEXT,
  contact_phone  TEXT,
  audit_status   INTEGER NOT NULL DEFAULT 0,
  audit_result   TEXT,
  audit_remark   TEXT,
  audited_at     TEXT,
  created_at     TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  FOREIGN KEY (resource_id) REFERENCES resource (resource_id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (apply_org_id) REFERENCES org (org_id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (target_org_id) REFERENCES org (org_id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (apply_user_id) REFERENCES sys_user (user_id) ON DELETE SET NULL ON UPDATE CASCADE
);
CREATE INDEX idx_auth_resource ON share_auth (resource_id);
CREATE INDEX idx_auth_apply_org ON share_auth (apply_org_id);
CREATE INDEX idx_auth_target_org ON share_auth (target_org_id);
CREATE INDEX idx_auth_status ON share_auth (audit_status);

-- 9. exhibition 数字展馆表
CREATE TABLE exhibition (
  exhibition_id   INTEGER PRIMARY KEY AUTOINCREMENT,
  exhibition_name TEXT NOT NULL,
  description     TEXT,
  cover_url       TEXT,
  status          INTEGER NOT NULL DEFAULT 0,
  created_at      TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  published_at    TEXT
);
CREATE INDEX idx_exhibition_status ON exhibition (status);

-- 10. exhibition_org 展馆-机构关联表
CREATE TABLE exhibition_org (
  exhibition_id INTEGER NOT NULL,
  org_id        INTEGER NOT NULL,
  PRIMARY KEY (exhibition_id, org_id),
  FOREIGN KEY (exhibition_id) REFERENCES exhibition (exhibition_id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (org_id) REFERENCES org (org_id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX idx_eo_org ON exhibition_org (org_id);

-- 11. exhibition_resource 展馆-资源关联表
CREATE TABLE exhibition_resource (
  exhibition_id INTEGER NOT NULL,
  resource_id   INTEGER NOT NULL,
  sort_order    INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (exhibition_id, resource_id),
  FOREIGN KEY (exhibition_id) REFERENCES exhibition (exhibition_id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (resource_id) REFERENCES resource (resource_id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX idx_er_resource ON exhibition_resource (resource_id);

-- 12. favorite 收藏表
CREATE TABLE favorite (
  favorite_id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id     INTEGER NOT NULL,
  resource_id INTEGER NOT NULL,
  created_at  TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  UNIQUE (user_id, resource_id),
  FOREIGN KEY (user_id) REFERENCES sys_user (user_id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (resource_id) REFERENCES resource (resource_id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX idx_fav_resource ON favorite (resource_id);

-- 13. download_record 下载记录表
CREATE TABLE download_record (
  download_id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id     INTEGER NOT NULL,
  resource_id INTEGER NOT NULL,
  ip          TEXT,
  created_at  TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  FOREIGN KEY (user_id) REFERENCES sys_user (user_id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (resource_id) REFERENCES resource (resource_id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX idx_dl_user ON download_record (user_id);
CREATE INDEX idx_dl_resource ON download_record (resource_id);

-- 14. browse_history 浏览历史表
CREATE TABLE browse_history (
  history_id  INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id     INTEGER NOT NULL,
  resource_id INTEGER NOT NULL,
  created_at  TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  FOREIGN KEY (user_id) REFERENCES sys_user (user_id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (resource_id) REFERENCES resource (resource_id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX idx_bh_user ON browse_history (user_id);
CREATE INDEX idx_bh_resource ON browse_history (resource_id);

-- 15. notification 通知表
CREATE TABLE notification (
  notification_id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id         INTEGER NOT NULL,
  type            TEXT NOT NULL,
  title           TEXT NOT NULL,
  content         TEXT,
  is_read         INTEGER NOT NULL DEFAULT 0,
  created_at      TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  FOREIGN KEY (user_id) REFERENCES sys_user (user_id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX idx_ntf_user ON notification (user_id);
CREATE INDEX idx_ntf_user_read ON notification (user_id, is_read);

-- 16. operation_log 操作日志表
CREATE TABLE operation_log (
  log_id      INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id     INTEGER,
  action      TEXT NOT NULL,
  target_type TEXT,
  target_id   INTEGER,
  detail      TEXT,
  ip          TEXT,
  created_at  TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  FOREIGN KEY (user_id) REFERENCES sys_user (user_id) ON DELETE SET NULL ON UPDATE CASCADE
);
CREATE INDEX idx_log_user ON operation_log (user_id);
CREATE INDEX idx_log_action ON operation_log (action);
CREATE INDEX idx_log_created ON operation_log (created_at);

-- ============================================================================
-- 种子数据（从 02_seed.sql 与 05_more_data.sql 抽取）
-- ============================================================================
-- ============================================================================
-- 红脉通 · 示例数据
-- 文件：02_seed.sql
-- 作用：往 01_schema.sql 建好的表里灌入演示数据
-- 执行：mysql -u root -p redmaitong < 02_seed.sql
--
-- 要点：
--   1. 这里【显式指定主键 id】（如 org_id=1、resource_id=1），
--      好处是后面03查询的结果可以精确对答案、好预测。
--      真实项目里一般让 AUTO_INCREMENT 自己生成，这里为了演示方便手动钉死。
--   2. 观察外键字段（org_id、category_id、resource_id）如何在 INSERT 里互相引用。
--   3. 先插"一"端（org、category、tag、resource、sys_user），再插"多"端和中间表，
--      否则外键会报错（比如 resource_tag 的 resource_id 必须先存在）。
-- ============================================================================


-- 清空数据（保证可重复执行）。注意顺序：先删"多"端和中间表，再删"一"端。


-- ----------------------------------------------------------------------------
-- 1. 机构（5 家示范机构，对应原型首页的 5 张机构卡片）
-- ----------------------------------------------------------------------------
INSERT INTO org (org_id, org_name, org_type, credit_code, address, contact_name, contact_phone, email, description, apply_reason, api_level, status) VALUES
(1, 'XX省综合档案馆',   'ARCH', '123456789012345678', '江西省南昌市红谷滩区学府大道100号', '张馆长', '13800138000', 'zhangguan@archive.org.cn', '省级综合性档案馆，馆藏建国以来大量地方报刊、档案卷宗。', '省级馆藏机构，期望接入平台共享馆藏数字化资源。', 2, 1),
(2, 'XX市革命历史纪念馆', 'MEM', '123456789012345679', '江西省南昌市八一大道200号', '李馆长', '13900139000', 'liguan@mem.org.cn', '革命历史类文博场馆，拥有大量革命文物与3D扫描资产。', NULL, 2, 1),
(3, 'XX县党史研究室',    'HIST', '123456789012345680', '江西省南昌市某县', '王主任', '13700137000', 'wang@hist.gov.cn', '地方党史研究机构，收藏口述历史音频、地方革命史料。', NULL, 1, 1),
(4, 'XX大学马克思主义学院', 'MARX', '123456789012345681', '江西省南昌市某高校', '陈老师', '13600136000', 'chen@marx.edu.cn', '高校马院，拥有党史教学课件与配套题库。', '高校教研单位，期望共享党史教研素材并参与联合展馆。', 1, 0),
(5, 'XX市文旅红色教育基地', 'CULT', '123456789012345682', '江西省南昌市某景区', '刘主任', '13500135000', 'liu@cult.org.cn', '文旅部门管辖的红色教育基地，拥有旧址VR全景资源。', NULL, 1, 1);


-- ----------------------------------------------------------------------------
-- 2. 用户（覆盖 4 种角色）
--    注意 password_hash 存的是 bcrypt 哈希（这里用 "password" 的哈希做示意），绝不存明文
-- ----------------------------------------------------------------------------
INSERT INTO sys_user (user_id, username, password_hash, phone, email, role, org_id, status) VALUES
(1, 'admin',            '$2b$10$61XGv/h/TEtjcxDcLyvzne4m28mMTkooiykyMDI7SQwwXXk26B.Oe', '13800000000', 'admin@redmaitong.org', 'PLATFORM_ADMIN', NULL, 1),
(2, 'zhangguan',        '$2b$10$61XGv/h/TEtjcxDcLyvzne4m28mMTkooiykyMDI7SQwwXXk26B.Oe', '13800138000', 'zhangguan@archive.org.cn', 'ORG_ADMIN', 1, 1),
(3, 'liguan',           '$2b$10$61XGv/h/TEtjcxDcLyvzne4m28mMTkooiykyMDI7SQwwXXk26B.Oe', '13900139000', 'liguan@mem.org.cn', 'ORG_ADMIN', 2, 1),
(4, 'chenlaoshi',       '$2b$10$61XGv/h/TEtjcxDcLyvzne4m28mMTkooiykyMDI7SQwwXXk26B.Oe', '13600136000', 'chen@marx.edu.cn', 'ORG_USER', 4, 1),
(5, 'wangxiaoming',     '$2b$10$61XGv/h/TEtjcxDcLyvzne4m28mMTkooiykyMDI7SQwwXXk26B.Oe', '13512345678', 'wang@personal.cn', 'INDIVIDUAL', NULL, 1);


-- ----------------------------------------------------------------------------
-- 3. 资源分类（6 个一级 + 17 个二级 = 23 行，自关联，parent_id 指向一级）
-- ----------------------------------------------------------------------------
-- 一级分类（parent_id = NULL）
INSERT INTO resource_category (category_id, category_name, parent_id, level, sort_order) VALUES
(1, '党史文献档案',     NULL, 1, 1),
(2, '革命文物3D/图像',  NULL, 1, 2),
(3, '红色影像视频',     NULL, 1, 3),
(4, '口述历史音频',     NULL, 1, 4),
(5, '红色教研素材',     NULL, 1, 5),
(6, '旧址全景VR',       NULL, 1, 6);

-- 二级分类（parent_id 指向对应一级）
INSERT INTO resource_category (category_id, category_name, parent_id, level, sort_order) VALUES
(7,  '报刊资料', 1, 2, 1),
(8,  '文献手稿', 1, 2, 2),
(9,  '档案卷宗', 1, 2, 3),
(10, '3D模型',   2, 2, 1),
(11, '文物图片', 2, 2, 2),
(12, '旧址影像', 2, 2, 3),
(13, '纪录片',   3, 2, 1),
(14, '电影',     3, 2, 2),
(15, '宣讲视频', 3, 2, 3),
(16, '老兵口述', 4, 2, 1),
(17, '访谈录音', 4, 2, 2),
(18, '讲解音频', 4, 2, 3),
(19, '教学课件', 5, 2, 1),
(20, '题库资料', 5, 2, 2),
(21, '研学方案', 5, 2, 3),
(22, 'VR全景',   6, 2, 1),
(23, '虚拟展厅', 6, 2, 2);


-- ----------------------------------------------------------------------------
-- 4. 标签
-- ----------------------------------------------------------------------------
INSERT INTO tag (tag_id, tag_name) VALUES
(1, '长征'),
(2, '抗战'),
(3, '建国初期'),
(4, '3D模型'),
(5, '文物'),
(6, '口述史'),
(7, '教学课件'),
(8, '纪录片');


-- ----------------------------------------------------------------------------
-- 5. 资源（10 份，对齐原型首页/资源库的演示卡片）
--    注意 category_id 填的是【二级分类】，org_id 对应上面机构
-- ----------------------------------------------------------------------------
INSERT INTO resource (resource_id, title, category_id, org_id, meta_desc, resource_year, share_level, cover_url, view_count, download_count, audit_status, created_at) VALUES
(1,  '建国初期地方报刊全套高清数字化档案',   7,  1, '涵盖1949-1960年地方党报、机关刊物共32种，合计18万页，TIFF高清扫描，支持全文检索。', '1949-1960', 2, 'https://cdn.redmaitong.org/res/1/cover.jpg', 13620, 2840, 1, '2026-03-15 10:30:00'),
(2,  '长征时期红军生活器具三维数字资产库',   10, 2, '高精度三维扫描，支持其他机构引用至专题展览。', '1934-1936', 2, 'https://cdn.redmaitong.org/res/2/cover.jpg', 9270, 1560, 1, '2026-04-02 09:15:00'),
(3,  '党史教学成套课件与配套题库合集',      19, 4, '面向全部教育类机构无限制开放共享。', '2020-2026', 1, 'https://cdn.redmaitong.org/res/3/cover.jpg', 27500, 8940, 1, '2026-05-12 14:20:00'),
(4,  '解放战争老兵口述历史原声录音库',      16, 3, '配套文字转录稿，机构可申请商用研学授权。', '1946-1949', 2, 'https://cdn.redmaitong.org/res/4/cover.jpg', 6840, 980, 1, '2026-05-20 11:00:00'),
(5,  '地方革命斗争史史料汇编数字版',        9,  3, '全文字检索，其他机构可提交共享调取申请。', '1921-1949', 2, 'https://cdn.redmaitong.org/res/5/cover.jpg', 4210, 620, 1, '2026-06-01 16:40:00'),
(6,  '本地革命旧址实拍修复纪录片合集',      13, 2, '完全开放，所有协同机构可直接下载引用。', '2018-2025', 1, 'https://cdn.redmaitong.org/res/6/cover.jpg', 3310, 1150, 1, '2026-06-10 10:10:00'),
(7,  '抗战时期军用物品三维数字模型集',      10, 1, '需提交机构使用授权后方可完整下载源文件。', '1937-1945', 2, 'https://cdn.redmaitong.org/res/7/cover.jpg', 2890, 410, 1, '2026-06-18 15:30:00'),
(8,  '红色主题班会全套教学资源包',          19, 4, '面向全部教育机构永久免费共享。', '2023-2026', 1, 'https://cdn.redmaitong.org/res/8/cover.jpg', 5120, 2230, 1, '2026-07-01 09:00:00'),
(9,  '长征红军煤油灯3D数字模型',           10, 2, '1935年长征时期实物三维扫描资产，支持360度旋转查看。', '1930-1949', 2, 'https://cdn.redmaitong.org/res/9/cover.jpg', 8760, 1240, 1, '2026-05-12 14:30:00'),
(10, '某地革命旧址VR全景漫游',             22, 5, '革命旧址720度VR全景展示，支持沉浸式浏览。', '2024-2026', 1, 'https://cdn.redmaitong.org/res/10/cover.jpg', 1980, 350, 0, '2026-07-15 13:45:00');


-- ----------------------------------------------------------------------------
-- 6. 资源-标签关联（一个资源可挂多个标签）
-- ----------------------------------------------------------------------------
INSERT INTO resource_tag (resource_id, tag_id) VALUES
(1, 3),                              -- 建国初期报刊 -> 建国初期
(2, 1), (2, 4), (2, 5),              -- 长征器具 -> 长征 / 3D模型 / 文物
(3, 7),                              -- 教学课件 -> 教学课件
(4, 6),                              -- 老兵口述 -> 口述史
(5, 1), (5, 3),                      -- 史料汇编 -> 长征 / 建国初期
(6, 8),                              -- 纪录片 -> 纪录片
(7, 2), (7, 4), (7, 5),              -- 抗战模型 -> 抗战 / 3D模型 / 文物
(8, 7),                              -- 班会资源包 -> 教学课件
(9, 1), (9, 4), (9, 5);              -- 煤油灯 -> 长征 / 3D模型 / 文物


-- ----------------------------------------------------------------------------
-- 7. 资源文件（一对多：资源2 有多个文件，其余各 1~2 个）
-- ----------------------------------------------------------------------------
INSERT INTO resource_file (file_id, resource_id, file_name, file_path, file_size, file_type, sort_order) VALUES
(1,  1, '报刊档案_第1卷.pdf',  'https://cdn.redmaitong.org/res/1/vol1.pdf',  52428800, 'pdf', 1),
(2,  1, '报刊档案_第2卷.pdf',  'https://cdn.redmaitong.org/res/1/vol2.pdf',  50135040, 'pdf', 2),
(3,  2, '红军水壶.glb',        'https://cdn.redmaitong.org/res/2/kettle.glb', 209715200, 'glb', 1),
(4,  2, '红军斗笠.glb',        'https://cdn.redmaitong.org/res/2/hat.glb',   178257920, 'glb', 2),
(5,  9, '煤油灯.glb',          'https://cdn.redmaitong.org/res/9/lamp.glb',  15728640, 'glb', 1),
(6,  3, '党史课件.ppt',        'https://cdn.redmaitong.org/res/3/course.ppt', 31457280, 'ppt', 1),
(7,  4, '老兵口述_原声.mp3',   'https://cdn.redmaitong.org/res/4/voice.mp3', 104857600, 'mp3', 1),
(8,  6, '旧址修复纪录片.mp4',  'https://cdn.redmaitong.org/res/6/doc.mp4',   524288000, 'mp4', 1),
(9,  10, '旧址VR全景.html',    'https://cdn.redmaitong.org/res/10/vr.html',   2097152, 'html', 1);


-- ----------------------------------------------------------------------------
-- 8. 共享授权申请（对齐原型"共享授权管理"页 3 条记录）
--    注意 apply_user_id：仅当申请机构在示例数据里有对应用户账号时填写，
--    党史研究室(org3)、文旅基地(org5) 没有示例用户，故填 NULL（外键允许为空）。
-- ----------------------------------------------------------------------------
INSERT INTO share_auth (auth_id, resource_id, apply_org_id, target_org_id, apply_user_id, apply_purpose, use_duration, contact_person, contact_phone, audit_status, audit_result, audit_remark, audited_at, created_at) VALUES
(1, 9, 4, 2, 4,    '校内党史研学课程使用，计划制作教学课件。', '6_months', '陈老师', '13600136000', 0, NULL, NULL, NULL, '2026-07-07 09:00:00'),
(2, 1, 3, 1, NULL, '联合数字展馆制作，需要引用部分报刊扫描件。', '1_year', '王主任', '13700137000', 1, '同意授权使用', '同意授权使用1年，需注明出处。', '2026-07-08 10:00:00', '2026-07-05 14:30:00'),
(3, 4, 5, 3, NULL, '红色旅游宣传制作，需引用口述音频片段。', '3_months', '刘主任', '13500135000', 0, NULL, NULL, NULL, '2026-07-10 11:20:00');


-- ----------------------------------------------------------------------------
-- 9. 数字展馆 + 参与机构 + 展品资源（对齐原型"联合专题展馆"页 3 个展馆）
-- ----------------------------------------------------------------------------
INSERT INTO exhibition (exhibition_id, exhibition_name, description, cover_url, status, published_at) VALUES
(1, '长征之路跨区域联合VR展馆', '多省市纪念馆文物、史料联合展出，沉浸式VR体验。', 'https://cdn.redmaitong.org/exh/1/cover.jpg', 1, '2026-06-01 10:00:00'),
(2, '百年地方党史文献数字长卷展', '档案史料+教研解读素材协同整合，线上数字长卷展示。', 'https://cdn.redmaitong.org/exh/2/cover.jpg', 1, '2026-06-15 10:00:00'),
(3, '英烈人物事迹全域联合陈列馆', '各地纪念馆英烈遗物、影像互通展出，致敬革命先烈。', 'https://cdn.redmaitong.org/exh/3/cover.jpg', 0, NULL);

-- 展馆-机构
INSERT INTO exhibition_org (exhibition_id, org_id) VALUES
(1, 1), (1, 2), (1, 3),            -- 长征馆：档案馆+纪念馆+党史研究室
(2, 1), (2, 4),                     -- 文献长卷：档案馆+高校马院
(3, 2), (3, 5);                     -- 英烈馆：纪念馆+文旅基地

-- 展馆-资源
INSERT INTO exhibition_resource (exhibition_id, resource_id, sort_order) VALUES
(1, 2, 1), (1, 9, 2), (1, 10, 3),
(2, 1, 1), (2, 5, 2),
(3, 4, 1), (3, 7, 2);


-- ----------------------------------------------------------------------------
-- 10. 用户行为：收藏 / 下载 / 浏览（以用户 2 张馆长为例，对应个人中心）
-- ----------------------------------------------------------------------------
INSERT INTO favorite (favorite_id, user_id, resource_id, created_at) VALUES
(1, 2, 1, '2026-07-15 10:00:00'),
(2, 2, 2, '2026-06-28 14:00:00'),
(3, 2, 4, '2026-05-10 09:00:00'),
(4, 2, 3, '2026-04-22 16:00:00');

INSERT INTO download_record (download_id, user_id, resource_id, ip, created_at) VALUES
(1, 2, 1, '10.0.0.5', '2026-07-16 09:30:00'),
(2, 2, 3, '10.0.0.5', '2026-07-01 11:00:00'),
(3, 4, 3, '10.0.0.8', '2026-06-20 15:20:00');

INSERT INTO browse_history (history_id, user_id, resource_id, created_at) VALUES
(1, 2, 1, '2026-07-18 08:00:00'),
(2, 2, 9, '2026-07-18 08:05:00'),
(3, 2, 3, '2026-07-18 08:10:00'),
(4, 4, 1, '2026-07-18 09:00:00');


-- ----------------------------------------------------------------------------
-- 11. 通知（对应 WebSocket 的几类消息）
-- ----------------------------------------------------------------------------
INSERT INTO notification (notification_id, user_id, type, title, content, is_read, created_at) VALUES
(1, 2, 'AUTH_AUDIT_RESULT',  '共享申请已通过',     '您提交的《地方革命斗争史史料汇编数字版》调取申请已通过。', 0, '2026-07-08 10:05:00'),
(2, 3, 'AUTH_AUDIT_RESULT',  '收到新的共享申请',   '高校马院向您申请调取《长征红军煤油灯3D数字模型》，请及时审批。', 1, '2026-07-07 09:05:00'),
(3, 4, 'EXHIBITION_INVITE',  '联合展馆邀请',       '您被邀请加入《百年地方党史文献数字长卷展》。', 0, '2026-06-20 10:00:00'),
(4, 2, 'SYSTEM_NOTICE',      '系统升级公告',       '平台将于本周六凌晨进行系统升级维护。', 1, '2026-07-01 09:00:00');


-- ----------------------------------------------------------------------------
-- 12. 操作日志（审计）
-- ----------------------------------------------------------------------------
INSERT INTO operation_log (log_id, user_id, action, target_type, target_id, detail, ip, created_at) VALUES
(1, 2, 'LOGIN',    NULL,       NULL, '用户登录成功', '10.0.0.5', '2026-07-18 08:00:00'),
(2, 2, 'DOWNLOAD', 'resource', 1,    '下载资源《建国初期地方报刊全套高清数字化档案》', '10.0.0.5', '2026-07-16 09:30:00'),
(3, 4, 'APPLY',    'share_auth', 1,  '提交跨机构调取申请', '10.0.0.8', '2026-07-07 09:00:00');


-- 灌数据完成，自检：
-- SELECT COUNT(*) FROM resource;   -> 10
-- SELECT COUNT(*) FROM org;        -> 5

-- ============================================================================
-- 红脉通 · 补充数据（在 02_seed.sql 基础上追加，不覆盖已有数据）
-- 文件：05_more_data.sql
-- 作用：把演示数据"补满"——
--   1. 机构从 5 家补到 14 家（覆盖 5 种类型 + 待审核/已认证/已禁用 3 种状态）
--   2. 用户从 5 个补到 19 个（4 种角色全覆盖，新增禁用用户示例）
--   3. 资源从 10 份补到 34 份（17 个二级分类全部用上，共享等级 1/2/3 全覆盖）
--   4. 补齐资源文件、标签、授权申请、展馆、收藏/下载/浏览、通知、日志
-- 执行：mysql -u root -p redmaitong < 05_more_data.sql
--
-- 重要：本文件是【追加式】，必须在 02_seed.sql 之后执行，且只执行一次。
--       如需重置，按 01 → 02 → 05 顺序重跑即可（02 会 TRUNCATE 清空，05 再追加）。
-- 注意：本文件的数据会让 03/04 里"预期结果"的注释不再精确（它们是按 02 的 10 份
--       资源写的），但不影响 SQL 本身的正确性。。
-- ============================================================================


-- 本文件只做 INSERT，依赖顺序如下：先"一"端（org/sys_user/tag/resource），
-- 再"多"端和中间表（resource_file/resource_tag/share_auth/exhibition/行为表/通知/日志）。
-- 所有显式 id 都从 02_seed 的末尾继续，避免与已有数据冲突。


-- ----------------------------------------------------------------------------
-- 1. 机构（追加 9 家，org_id 6~14；覆盖 5 种类型、3 种状态）
--    注意 org10 是"待审核"、org13 是"已禁用"，用来演示审核/禁用两种边界状态。
-- ----------------------------------------------------------------------------
INSERT INTO org (org_id, org_name, org_type, credit_code, address, contact_name, contact_phone, email, description, apply_reason, api_level, status) VALUES
(6,  '延安革命纪念馆',            'MEM',  '123456789012345683', '陕西省延安市宝塔区杨家岭路1号',    '高馆长', '13700137001', 'gao@yanan.mem.org.cn',     '全国爱国主义教育示范基地，馆藏延安时期珍贵文物与文献手稿。', NULL, 2, 1),
(7,  '井冈山红色旅游景区管委会',   'CULT', '123456789012345684', '江西省井冈山市茨坪镇红军南路2号',  '周主任', '13700137002', 'zhou@jgs.cult.org.cn',     '井冈山革命根据地旧址群管理单位，拥有VR全景与讲解音频资源。', NULL, 1, 1),
(8,  'XX市党史和文献研究院',      'HIST', '123456789012345685', '湖南省长沙市芙蓉区韶山北路3号',    '何主任', '13700137003', 'he@dangshi.gov.cn',        '地方党史研究机构，收藏党史影像、口述史料与文献手稿。', NULL, 2, 1),
(9,  'XX师范大学马克思主义学院',   'MARX', '123456789012345686', '北京市海淀区学院路4号',            '杨老师', '13700137004', 'yang@shifan.edu.cn',       '高校马院，拥有党史宣讲视频、教学课件与竞赛题库。', NULL, 1, 1),
(10, 'XX省档案馆',                'ARCH', '123456789012345687', '四川省成都市武侯区档案馆路5号',    '罗馆长', '13700137005', 'luo@archive.org.cn',       '省级综合档案馆，馆藏苏区时期档案卷宗，待接入平台。', '省级馆藏机构，申请接入平台共享苏区档案数字化资源。', 2, 0),
(11, '遵义会议纪念馆',            'MEM',  '123456789012345688', '贵州省遵义市红花岗区子尹路6号',    '马馆长', '13700137006', 'ma@zunyi.mem.org.cn',      '遵义会议会址纪念场馆，拥有旧址影像与烈士书信手稿。', NULL, 2, 1),
(12, '西柏坡纪念馆',              'MEM',  '123456789012345689', '河北省石家庄市平山县西柏坡镇7号',  '董馆长', '13700137007', 'dong@xibaipo.mem.org.cn',  '西柏坡革命纪念场馆，拥有电报手稿与3D文物扫描资产。', NULL, 1, 1),
(13, 'XX县档案馆',                'ARCH', '123456789012345690', '湖北省黄冈市某县档案馆路8号',      '许馆长', '13700137008', 'xu@xian.archive.org.cn',   '县级档案馆，因资质年检问题暂停合作。', NULL, 1, 2),
(14, 'XX学院马克思主义学院',      'MARX', '123456789012345691', '广东省广州市天河区学院路9号',      '孙老师', '13700137009', 'sun@xueyuan.edu.cn',       '高校马院，拥有红色研学方案与家风宣讲视频。', NULL, 1, 1);


-- ----------------------------------------------------------------------------
-- 2. 用户（追加 14 个，user_id 6~19；覆盖 4 种角色，含 1 个禁用用户）
--    注意：org10（待审核）/org13（已禁用）没有创建用户——入驻未通过或已禁用的
--    机构不产生可登录账号，与真实流程一致。user13 是"禁用"示例（status=0）。
-- ----------------------------------------------------------------------------
INSERT INTO sys_user (user_id, username, password_hash, phone, email, role, org_id, status) VALUES
(6,  'gaoguan',     '$2b$10$61XGv/h/TEtjcxDcLyvzne4m28mMTkooiykyMDI7SQwwXXk26B.Oe', '13800138001', 'gao@yanan.mem.org.cn',     'ORG_ADMIN', 6,  1),
(7,  'yanan_staff', '$2b$10$61XGv/h/TEtjcxDcLyvzne4m28mMTkooiykyMDI7SQwwXXk26B.Oe', '13800138002', 'staff1@yanan.mem.org.cn',  'ORG_USER',  6,  1),
(8,  'zhouzhuren',  '$2b$10$61XGv/h/TEtjcxDcLyvzne4m28mMTkooiykyMDI7SQwwXXk26B.Oe', '13800138003', 'zhou@jgs.cult.org.cn',     'ORG_ADMIN', 7,  1),
(9,  'jgs_staff',   '$2b$10$61XGv/h/TEtjcxDcLyvzne4m28mMTkooiykyMDI7SQwwXXk26B.Oe', '13800138004', 'staff2@jgs.cult.org.cn',   'ORG_USER',  7,  1),
(10, 'hedangshi',   '$2b$10$61XGv/h/TEtjcxDcLyvzne4m28mMTkooiykyMDI7SQwwXXk26B.Oe', '13800138005', 'he@dangshi.gov.cn',        'ORG_ADMIN', 8,  1),
(11, 'ds_staff',    '$2b$10$61XGv/h/TEtjcxDcLyvzne4m28mMTkooiykyMDI7SQwwXXk26B.Oe', '13800138006', 'staff3@dangshi.gov.cn',    'ORG_USER',  8,  1),
(12, 'yangmks',     '$2b$10$61XGv/h/TEtjcxDcLyvzne4m28mMTkooiykyMDI7SQwwXXk26B.Oe', '13800138007', 'yang@shifan.edu.cn',       'ORG_ADMIN', 9,  1),
(13, 'sf_staff',    '$2b$10$61XGv/h/TEtjcxDcLyvzne4m28mMTkooiykyMDI7SQwwXXk26B.Oe', '13800138008', 'staff4@shifan.edu.cn',     'ORG_USER',  9,  0),
(14, 'maguan',      '$2b$10$61XGv/h/TEtjcxDcLyvzne4m28mMTkooiykyMDI7SQwwXXk26B.Oe', '13800138009', 'ma@zunyi.mem.org.cn',      'ORG_ADMIN', 11, 1),
(15, 'dongguan',    '$2b$10$61XGv/h/TEtjcxDcLyvzne4m28mMTkooiykyMDI7SQwwXXk26B.Oe', '13800138010', 'dong@xibaipo.mem.org.cn',  'ORG_ADMIN', 12, 1),
(16, 'xbp_staff',   '$2b$10$61XGv/h/TEtjcxDcLyvzne4m28mMTkooiykyMDI7SQwwXXk26B.Oe', '13800138011', 'staff5@xibaipo.mem.org.cn','ORG_USER',  12, 1),
(17, 'lihua',       '$2b$10$61XGv/h/TEtjcxDcLyvzne4m28mMTkooiykyMDI7SQwwXXk26B.Oe', '13800138012', 'lihua@personal.cn',        'INDIVIDUAL', NULL, 1),
(18, 'wangfang',    '$2b$10$61XGv/h/TEtjcxDcLyvzne4m28mMTkooiykyMDI7SQwwXXk26B.Oe', '13800138013', 'wangfang@personal.cn',     'INDIVIDUAL', NULL, 1),
(19, 'sunmks',      '$2b$10$61XGv/h/TEtjcxDcLyvzne4m28mMTkooiykyMDI7SQwwXXk26B.Oe', '13800138014', 'sun@xueyuan.edu.cn',       'ORG_ADMIN', 14, 1);


-- ----------------------------------------------------------------------------
-- 3. 标签（追加 10 个，tag_id 9~18）
-- ----------------------------------------------------------------------------
INSERT INTO tag (tag_id, tag_name) VALUES
(9,  '井冈山'),
(10, '延安'),
(11, '遵义会议'),
(12, '西柏坡'),
(13, '影像资料'),
(14, '文物图片'),
(15, '研学'),
(16, '题库'),
(17, '苏区'),
(18, '家书');


-- ----------------------------------------------------------------------------
-- 4. 资源（追加 24 份，resource_id 11~34）
--    设计目标：
--      a. 让 17 个二级分类【全部】有资源（02 里空的 10 个分类这次全部补齐）
--      b. share_level 1/2/3 全覆盖（resource 23 是"3级机构内部"）
--      c. audit_status 0/1/2/3 全覆盖（21/33待审、26驳回、31下架）
--      d. 待审/驳回/下架的资源 view_count、download_count 保持 0，符合"未发布无流量"
-- ----------------------------------------------------------------------------
INSERT INTO resource (resource_id, title, category_id, org_id, meta_desc, resource_year, share_level, cover_url, view_count, download_count, audit_status, created_at) VALUES
(11, '延安时期重要文献手稿影印集',         8,  6,  '收录延安时期中央文件、讲话手稿百余份，高清影印，支持逐页缩放浏览。', '1935-1948', 2, 'https://cdn.redmaitong.org/res/11/cover.jpg', 5420, 860, 1, '2026-04-18 09:40:00'),
(12, '井冈山斗争时期革命文物高清图片库',   11, 7,  '井冈山根据地时期军旗、武器、生活器具等文物高清正摄图片，含多角度细节。', '1927-1929', 1, 'https://cdn.redmaitong.org/res/12/cover.jpg', 7330, 1920, 1, '2026-05-06 14:10:00'),
(13, '遵义会议旧址历史影像资料',           12, 11, '遵义会议会址及周边旧址的历史照片与修复影像，附拍摄年代说明。', '1935-1960', 1, 'https://cdn.redmaitong.org/res/13/cover.jpg', 6180, 1210, 1, '2026-05-22 10:00:00'),
(14, '红色经典电影《地道战》数字修复版',   14, 8,  '经典红色电影4K数字修复版，含字幕与解说音轨，供教研放映引用。', '1965', 1, 'https://cdn.redmaitong.org/res/14/cover.jpg', 8840, 2340, 1, '2026-06-02 15:30:00'),
(15, '新时代党史宣讲精品视频合集',         15, 9,  '面向基层的党史宣讲视频12讲，配套讲义，支持在线点播与引用。', '2021-2025', 1, 'https://cdn.redmaitong.org/res/15/cover.jpg', 11260, 3560, 1, '2026-06-08 11:20:00'),
(16, '老红军后代访谈录音汇编',             17, 6,  '多位老红军后代口述家史录音，附文字转录稿，用于家风家史研究。', '2020-2024', 2, 'https://cdn.redmaitong.org/res/16/cover.jpg', 2980, 410, 1, '2026-06-14 09:00:00'),
(17, '革命旧址现场讲解音频库',             18, 12, '西柏坡等旧址现场讲解员标准讲解音频，支持线上收听与导览引用。', '2019-2025', 1, 'https://cdn.redmaitong.org/res/17/cover.jpg', 2560, 380, 1, '2026-06-20 14:50:00'),
(18, '党史知识竞赛题库（含答案解析）',     20, 9,  '党史知识竞赛题库2000题，含单选/多选/判断与答案解析，可导入在线考试。', '2022-2026', 1, 'https://cdn.redmaitong.org/res/18/cover.jpg', 9340, 4210, 1, '2026-06-26 10:30:00'),
(19, '红色研学旅行方案汇编',               21, 14, '多条红色研学线路设计方案，含行程、课程与安全预案，供学校参考使用。', '2023-2026', 1, 'https://cdn.redmaitong.org/res/19/cover.jpg', 1870, 640, 1, '2026-07-02 09:10:00'),
(20, '井冈山革命根据地虚拟展厅',           23, 7,  '井冈山革命根据地720度虚拟展厅，支持沉浸式导览与热点讲解。', '2024-2026', 1, 'https://cdn.redmaitong.org/res/20/cover.jpg', 3450, 520, 1, '2026-07-06 13:20:00'),
(21, '中央苏区土地改革档案卷宗',           9,  8,  '中央苏区时期土地改革档案卷宗扫描件，含政策文件与登记名册。', '1931-1934', 2, 'https://cdn.redmaitong.org/res/21/cover.jpg', 0, 0, 0, '2026-07-20 10:00:00'),
(22, '西柏坡时期电报手稿汇编',             8,  12, '西柏坡时期重要电报手稿原件影印，附电报背景与内容解读。', '1947-1949', 2, 'https://cdn.redmaitong.org/res/22/cover.jpg', 4210, 680, 1, '2026-06-30 16:00:00'),
(23, '革命根据地地图与文物图片集',         11, 6,  '各革命根据地历史地图与馆藏文物图片合集（内部参考资料）。', '1927-1949', 3, 'https://cdn.redmaitong.org/res/23/cover.jpg', 1130, 90, 1, '2026-07-03 09:50:00'),
(24, '抗战题材红色电影《平原游击队》',     14, 8,  '经典抗战电影数字修复版，供爱国主义教育与教学放映使用。', '1955', 1, 'https://cdn.redmaitong.org/res/24/cover.jpg', 5160, 1780, 1, '2026-07-08 14:40:00'),
(25, '红色家风主题宣讲视频',               15, 14, '红色家风传承主题宣讲视频8讲，面向基层党员与家庭教育使用。', '2022-2026', 1, 'https://cdn.redmaitong.org/res/25/cover.jpg', 2480, 720, 1, '2026-07-11 10:20:00'),
(26, '苏区时期报刊资料电子版',             7,  8,  '苏区时期红色报刊电子扫描版（内容尚在核对，暂未通过审核）。', '1931-1934', 2, 'https://cdn.redmaitong.org/res/26/cover.jpg', 0, 0, 2, '2026-07-12 09:30:00'),
(27, '长征路上红色歌谣音频专辑',           18, 11, '长征沿线红色歌谣原声与录制音频，附歌词与传唱背景介绍。', '2020-2026', 1, 'https://cdn.redmaitong.org/res/27/cover.jpg', 3590, 940, 1, '2026-07-14 15:00:00'),
(28, '马克思主义经典原著导读课件',         19, 9,  '马克思主义经典原著导读系列课件，含导读提纲与思考题。', '2021-2026', 1, 'https://cdn.redmaitong.org/res/28/cover.jpg', 6270, 2890, 1, '2026-07-16 11:10:00'),
(29, '延安整风运动史料汇编',               9,  6,  '延安整风运动相关史料与文献汇编，支持全文检索与关键词定位。', '1942-1945', 2, 'https://cdn.redmaitong.org/res/29/cover.jpg', 2840, 450, 1, '2026-07-17 16:30:00'),
(30, '革命烈士书信手稿数字化档案',         8,  11, '革命烈士家书、遗书手稿数字化档案，附人物生平与背景注释。', '1921-1949', 2, 'https://cdn.redmaitong.org/res/30/cover.jpg', 6720, 1130, 1, '2026-07-19 09:20:00'),
(31, '红色旅游研学实践基地VR全景',         22, 7,  '红色旅游研学实践基地VR全景漫游（临时下架维护中）。', '2022-2026', 1, 'https://cdn.redmaitong.org/res/31/cover.jpg', 1420, 210, 3, '2026-06-24 10:40:00'),
(32, '抗战时期革命文物3D扫描模型',         10, 12, '抗战时期枪械、军装等革命文物高精度3D扫描模型，支持360度查看。', '1937-1945', 2, 'https://cdn.redmaitong.org/res/32/cover.jpg', 3980, 760, 1, '2026-07-04 14:00:00'),
(33, '党史知识思维导图课件',               19, 14, '党史知识体系思维导图课件，适合课堂展示与复习梳理。', '2025-2026', 1, 'https://cdn.redmaitong.org/res/33/cover.jpg', 0, 0, 0, '2026-07-22 09:00:00'),
(34, '口述历史老兵访谈第二辑',             16, 8,  '口述历史项目老兵访谈录音第二辑，含人物档案与转录稿。', '2021-2025', 2, 'https://cdn.redmaitong.org/res/34/cover.jpg', 2650, 380, 1, '2026-07-21 15:20:00');


-- ----------------------------------------------------------------------------
-- 5. 资源-标签关联（追加；一个资源可挂多个标签，标签来自 02 已有 + 本文件新增）
-- ----------------------------------------------------------------------------
INSERT INTO resource_tag (resource_id, tag_id) VALUES
(11, 10), (11, 14),                 -- 延安手稿 -> 延安 / 文物图片
(12, 9),  (12, 14),                 -- 井冈山图片 -> 井冈山 / 文物图片
(13, 11), (13, 13),                 -- 遵义影像 -> 遵义会议 / 影像资料
(14, 2),  (14, 13),                 -- 地道战 -> 抗战 / 影像资料
(15, 13),                           -- 宣讲视频 -> 影像资料
(16, 6),  (16, 10),                 -- 老红军后代 -> 口述史 / 延安
(17, 12), (17, 6),                  -- 西柏坡讲解 -> 西柏坡 / 口述史
(18, 16),                           -- 题库 -> 题库
(19, 15), (19, 9),                  -- 研学方案 -> 研学 / 井冈山
(20, 9),                            -- 井冈山虚拟展厅 -> 井冈山
(21, 17),                           -- 苏区档案 -> 苏区
(22, 12),                           -- 西柏坡手稿 -> 西柏坡
(23, 14),                           -- 根据地地图 -> 文物图片
(24, 2),  (24, 13),                 -- 平原游击队 -> 抗战 / 影像资料
(25, 13),                           -- 家风宣讲 -> 影像资料
(26, 17),                           -- 苏区报刊 -> 苏区
(27, 1),                            -- 长征歌谣 -> 长征
(28, 7),                            -- 马原导读课件 -> 教学课件
(29, 10),                           -- 延安整风史料 -> 延安
(30, 18),                           -- 烈士书信 -> 家书
(31, 9),                            -- 研学基地VR -> 井冈山
(32, 2),  (32, 4),  (32, 5),        -- 抗战3D模型 -> 抗战 / 3D模型 / 文物
(33, 7),                            -- 思维导图课件 -> 教学课件
(34, 6);                            -- 老兵访谈 -> 口述史


-- ----------------------------------------------------------------------------
-- 6. 资源文件（追加，file_id 11~37；一对多：资源 12/15/32 各挂了多个文件）
-- ----------------------------------------------------------------------------
INSERT INTO resource_file (file_id, resource_id, file_name, file_path, file_size, file_type, sort_order) VALUES
(11, 11, '延安手稿_影印集.pdf',     'https://cdn.redmaitong.org/res/11/manuscript.pdf',  83886080,  'pdf',  1),
(12, 12, '井冈山文物图片_军旗.jpg', 'https://cdn.redmaitong.org/res/12/flag.jpg',       5242880,   'jpg',  1),
(13, 12, '井冈山文物图片_武器.jpg', 'https://cdn.redmaitong.org/res/12/weapon.jpg',     4718592,   'jpg',  2),
(14, 13, '遵义会址_历史照片.jpg',   'https://cdn.redmaitong.org/res/13/photo.jpg',      6291456,   'jpg',  1),
(15, 14, '地道战_数字修复版.mp4',   'https://cdn.redmaitong.org/res/14/didaozhan.mp4', 1572864000,'mp4',  1),
(16, 15, '党史宣讲_第1讲.mp4',      'https://cdn.redmaitong.org/res/15/lecture1.mp4',  262144000, 'mp4',  1),
(17, 15, '党史宣讲_讲义.pdf',       'https://cdn.redmaitong.org/res/15/lecture.pdf',   15728640,  'pdf',  2),
(18, 16, '老红军后代访谈_原声.mp3', 'https://cdn.redmaitong.org/res/16/interview.mp3', 73400320,  'mp3',  1),
(19, 17, '西柏坡旧址讲解.mp3',      'https://cdn.redmaitong.org/res/17/guide.mp3',     52428800,  'mp3',  1),
(20, 18, '党史题库.xlsx',           'https://cdn.redmaitong.org/res/18/bank.xlsx',     20971520,  'xlsx', 1),
(21, 19, '红色研学方案汇编.pdf',    'https://cdn.redmaitong.org/res/19/study.pdf',     10485760,  'pdf',  1),
(22, 20, '井冈山虚拟展厅.html',     'https://cdn.redmaitong.org/res/20/vr.html',       4194304,   'html', 1),
(23, 21, '苏区土地改革档案_卷1.pdf','https://cdn.redmaitong.org/res/21/land1.pdf',    104857600, 'pdf',  1),
(24, 22, '西柏坡电报手稿.pdf',      'https://cdn.redmaitong.org/res/22/telegram.pdf',  62914560,  'pdf',  1),
(25, 23, '根据地地图集.pdf',        'https://cdn.redmaitong.org/res/23/map.pdf',       20971520,  'pdf',  1),
(26, 24, '平原游击队.mp4',          'https://cdn.redmaitong.org/res/24/pingyuan.mp4',  1258291200,'mp4',  1),
(27, 25, '红色家风宣讲_第1讲.mp4',  'https://cdn.redmaitong.org/res/25/family1.mp4',  209715200, 'mp4',  1),
(28, 26, '苏区报刊_电子版.pdf',     'https://cdn.redmaitong.org/res/26/newspaper.pdf', 157286400, 'pdf',  1),
(29, 27, '长征红色歌谣.mp3',        'https://cdn.redmaitong.org/res/27/song.mp3',      83886080,  'mp3',  1),
(30, 28, '马原导读课件.ppt',        'https://cdn.redmaitong.org/res/28/marx.ppt',      31457280,  'ppt',  1),
(31, 29, '延安整风史料汇编.pdf',    'https://cdn.redmaitong.org/res/29/yanan.pdf',     73400320,  'pdf',  1),
(32, 30, '烈士书信手稿.pdf',        'https://cdn.redmaitong.org/res/30/letter.pdf',    41943040,  'pdf',  1),
(33, 31, '研学基地VR全景.html',     'https://cdn.redmaitong.org/res/31/vr.html',       3145728,   'html', 1),
(34, 32, '抗战枪械.glb',            'https://cdn.redmaitong.org/res/32/rifle.glb',     104857600, 'glb',  1),
(35, 32, '抗战军装.glb',            'https://cdn.redmaitong.org/res/32/uniform.glb',   94371840,  'glb',  2),
(36, 33, '党史思维导图课件.ppt',    'https://cdn.redmaitong.org/res/33/mindmap.ppt',   10485760,  'ppt',  1),
(37, 34, '老兵访谈第二辑.mp3',      'https://cdn.redmaitong.org/res/34/veteran2.mp3',  94371840,  'mp3',  1);


-- ----------------------------------------------------------------------------
-- 7. 共享授权申请（追加 8 条，auth_id 4~11；覆盖 0待审/1通过/2驳回/3过期 全部状态）
--    只对 share_level 2/3 的资源发起申请（1级公开资源无需授权），符合业务逻辑。
-- ----------------------------------------------------------------------------
INSERT INTO share_auth (auth_id, resource_id, apply_org_id, target_org_id, apply_user_id, apply_purpose, use_duration, contact_person, contact_phone, audit_status, audit_result, audit_remark, audited_at, created_at) VALUES
(4,  22, 9,  12, 12, '高校马院联合展馆制作，需引用西柏坡电报手稿。', '6_months', '杨老师', '13800138007', 0, NULL, NULL, NULL, '2026-07-10 10:00:00'),
(5,  30, 8,  11, 10, '地方党史展览，需引用烈士书信手稿。', '1_year', '何主任', '13800138005', 1, '同意授权使用', '同意授权1年，需注明出处。', '2026-07-11 10:00:00', '2026-07-09 09:00:00'),
(6,  16, 14, 6,  19, '高校红色家风课程建设，需引用老红军后代访谈。', '6_months', '孙老师', '13800138014', 0, NULL, NULL, NULL, '2026-07-12 09:00:00'),
(7,  29, 12, 6,  15, '西柏坡纪念馆联合专题展，需引用延安整风史料。', '1_year', '董馆长', '13800138010', 1, '同意授权使用', '同意授权1年。', '2026-07-13 10:00:00', '2026-07-12 14:00:00'),
(8,  23, 8,  6,  10, '党史研究需要，申请调取内部参考资料。', '3_months', '何主任', '13800138005', 2, '不予授权', '该资料为机构内部资料，暂不对外共享。', '2026-07-13 10:30:00', '2026-07-12 11:00:00'),
(9,  32, 9,  12, 12, '高校数字化教学，需引用抗战3D文物模型。', '6_months', '杨老师', '13800138007', 0, NULL, NULL, NULL, '2026-07-14 10:00:00'),
(10, 34, 11, 8,  14, '遵义纪念馆口述史项目，需引用老兵访谈音频。', '3_months', '马馆长', '13800138009', 1, '同意授权使用', '同意授权3个月。', '2026-07-15 10:00:00', '2026-07-14 09:00:00'),
(11, 11, 12, 6,  15, '西柏坡纪念馆专题陈列，需引用延安手稿影印件。', '1_year', '董馆长', '13800138010', 3, '授权已过期', '授权到期，未续期。', '2026-03-01 10:00:00', '2025-12-01 09:00:00');


-- ----------------------------------------------------------------------------
-- 8. 数字展馆 + 参与机构 + 展品资源（追加 3 个展馆，exhibition_id 4~6）
-- ----------------------------------------------------------------------------
INSERT INTO exhibition (exhibition_id, exhibition_name, description, cover_url, status, published_at) VALUES
(4, '延安精神主题联合展馆',       '延安时期文献手稿、口述史料与宣讲影像联合展出。', 'https://cdn.redmaitong.org/exh/4/cover.jpg', 1, '2026-06-28 10:00:00'),
(5, '中央苏区土地革命专题数字展', '苏区时期档案、报刊协同整合，线上专题展示（草稿中）。', 'https://cdn.redmaitong.org/exh/5/cover.jpg', 0, NULL),
(6, '西柏坡—赶考之路专题展',     '西柏坡电报手稿、3D文物与讲解音频联合展出。', 'https://cdn.redmaitong.org/exh/6/cover.jpg', 1, '2026-07-01 10:00:00');

-- 展馆-机构
INSERT INTO exhibition_org (exhibition_id, org_id) VALUES
(4, 6), (4, 8), (4, 9),            -- 延安精神馆：延安纪念馆+党史研究院+师大马院
(5, 8), (5, 10),                    -- 苏区专题展：党史研究院+省档案馆（待审核机构参与草稿展馆）
(6, 12), (6, 9);                    -- 赶考之路展：西柏坡纪念馆+师大马院

-- 展馆-资源
INSERT INTO exhibition_resource (exhibition_id, resource_id, sort_order) VALUES
(4, 11, 1), (4, 16, 2), (4, 29, 3),
(5, 21, 1), (5, 26, 2),
(6, 22, 1), (6, 32, 2), (6, 17, 3);


-- ----------------------------------------------------------------------------
-- 9. 用户行为：收藏 / 下载 / 浏览（分散到新增用户上，对应各人"个人中心"）
-- ----------------------------------------------------------------------------
INSERT INTO favorite (favorite_id, user_id, resource_id, created_at) VALUES
(5,  6,  11, '2026-07-20 09:00:00'),
(6,  6,  16, '2026-07-21 10:00:00'),
(7,  8,  20, '2026-07-18 11:00:00'),
(8,  12, 28, '2026-07-19 14:00:00'),
(9,  14, 13, '2026-07-22 09:30:00'),
(10, 17, 12, '2026-07-23 15:00:00'),
(11, 18, 18, '2026-07-24 10:20:00'),
(12, 15, 22, '2026-07-25 16:10:00');

INSERT INTO download_record (download_id, user_id, resource_id, ip, created_at) VALUES
(4,  6,  11, '10.0.1.5', '2026-07-21 09:40:00'),
(5,  8,  12, '10.0.2.8', '2026-07-19 14:10:00'),
(6,  12, 18, '10.0.3.6', '2026-07-20 11:30:00'),
(7,  14, 13, '10.0.4.9', '2026-07-22 10:00:00'),
(8,  17, 12, '10.0.5.7', '2026-07-23 15:20:00'),
(9,  18, 28, '10.0.6.4', '2026-07-24 16:00:00'),
(10, 15, 22, '10.0.7.2', '2026-07-25 17:30:00');

INSERT INTO browse_history (history_id, user_id, resource_id, created_at) VALUES
(5,  6,  11, '2026-07-21 09:00:00'),
(6,  6,  16, '2026-07-21 09:10:00'),
(7,  8,  20, '2026-07-19 13:50:00'),
(8,  8,  12, '2026-07-19 14:00:00'),
(9,  12, 28, '2026-07-20 11:00:00'),
(10, 12, 18, '2026-07-20 11:20:00'),
(11, 14, 13, '2026-07-22 09:40:00'),
(12, 17, 12, '2026-07-23 15:00:00'),
(13, 18, 28, '2026-07-24 15:40:00'),
(14, 15, 22, '2026-07-25 16:00:00');


-- ----------------------------------------------------------------------------
-- 10. 通知（追加；覆盖 4 种类型：授权审批/资源审核/展馆邀请/系统公告）
-- ----------------------------------------------------------------------------
INSERT INTO notification (notification_id, user_id, type, title, content, is_read, created_at) VALUES
(5,  6,  'RESOURCE_AUDIT_RESULT', '资源审核通过',   '您上传的《延安时期重要文献手稿影印集》已通过审核并发布。', 0, '2026-04-19 10:00:00'),
(6,  12, 'AUTH_AUDIT_RESULT',     '共享申请已通过', '您提交的《革命烈士书信手稿数字化档案》调取申请已通过。', 0, '2026-07-11 10:00:00'),
(7,  14, 'AUTH_AUDIT_RESULT',     '收到新的共享申请', '党史研究院向您申请调取《遵义会议旧址历史影像资料》，请及时审批。', 0, '2026-07-12 09:00:00'),
(8,  8,  'EXHIBITION_INVITE',     '联合展馆邀请',   '您被邀请加入《延安精神主题联合展馆》。', 0, '2026-06-28 10:00:00'),
(9,  9,  'EXHIBITION_INVITE',     '联合展馆邀请',   '您被邀请加入《西柏坡—赶考之路专题展》。', 1, '2026-06-29 10:00:00'),
(10, 17, 'SYSTEM_NOTICE',         '系统升级公告',   '平台将于本周六凌晨进行系统升级维护。', 0, '2026-07-25 09:00:00'),
(11, 10, 'AUTH_AUDIT_RESULT',     '共享申请被驳回', '您申请的《革命根据地地图与文物图片集》未获授权。', 1, '2026-07-13 10:00:00');


-- ----------------------------------------------------------------------------
-- 11. 操作日志（追加；覆盖 UPLOAD/APPLY/AUDIT/LOGIN/DOWNLOAD 等动作）
-- ----------------------------------------------------------------------------
INSERT INTO operation_log (log_id, user_id, action, target_type, target_id, detail, ip, created_at) VALUES
(4,  6,  'UPLOAD',   'resource',   11, '上传资源《延安时期重要文献手稿影印集》', '10.0.1.5', '2026-04-18 09:40:00'),
(5,  12, 'UPLOAD',   'resource',   28, '上传资源《马克思主义经典原著导读课件》', '10.0.3.6', '2026-07-16 11:10:00'),
(6,  14, 'APPLY',    'share_auth', 6,  '提交跨机构调取申请', '10.0.4.9', '2026-07-12 09:00:00'),
(7,  6,  'AUDIT',    'share_auth', 6,  '审批共享申请，结果=1', '10.0.1.5', '2026-07-12 10:00:00'),
(8,  17, 'LOGIN',    NULL,         NULL, '用户登录成功', '10.0.5.7', '2026-07-23 15:00:00'),
(9,  18, 'DOWNLOAD', 'resource',   28, '下载资源《马克思主义经典原著导读课件》', '10.0.6.4', '2026-07-24 16:00:00'),
(10, 8,  'AUDIT',    'org',        10, '审核机构入驻申请', '10.0.2.8', '2026-07-01 10:00:00');


-- ----------------------------------------------------------------------------
-- 12. 自检：跑完本文件后，以下 SELECT 应分别返回括号内的数字
-- ----------------------------------------------------------------------------
-- SELECT COUNT(*) FROM org;                -- 14（5 + 9）
-- SELECT COUNT(*) FROM sys_user;           -- 19（5 + 14）
-- SELECT COUNT(*) FROM tag;                -- 18（8 + 10）
-- SELECT COUNT(*) FROM resource;           -- 34（10 + 24）
-- SELECT COUNT(*) FROM resource_file;      -- 36（9 + 27）
-- SELECT COUNT(*) FROM resource_tag;       -- 50（16 + 34）
-- SELECT COUNT(*) FROM share_auth;         -- 11（3 + 8）
-- SELECT COUNT(*) FROM exhibition;         -- 6（3 + 3）
-- SELECT COUNT(*) FROM favorite;           -- 12（4 + 8）
-- SELECT COUNT(*) FROM download_record;    -- 10（3 + 7）
-- SELECT COUNT(*) FROM browse_history;     -- 14（4 + 10）
-- SELECT COUNT(*) FROM notification;       -- 11（4 + 7）
-- SELECT COUNT(*) FROM operation_log;      -- 10（3 + 7）
--
-- 顺带验证"17 个二级分类全部有资源"：
-- SELECT c.category_id, c.category_name, COUNT(r.resource_id) AS cnt
-- FROM resource_category c
-- LEFT JOIN resource r ON r.category_id = c.category_id
-- WHERE c.level = 2
-- GROUP BY c.category_id, c.category_name
-- ORDER BY c.category_id;   -- cnt 列应全部 >= 1
