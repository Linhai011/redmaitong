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

USE redmaitong;

-- 清空数据（保证可重复执行）。注意顺序：先删"多"端和中间表，再删"一"端。
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE operation_log;
TRUNCATE TABLE notification;
TRUNCATE TABLE browse_history;
TRUNCATE TABLE download_record;
TRUNCATE TABLE favorite;
TRUNCATE TABLE exhibition_resource;
TRUNCATE TABLE exhibition_org;
TRUNCATE TABLE exhibition;
TRUNCATE TABLE share_auth;
TRUNCATE TABLE resource_file;
TRUNCATE TABLE resource_tag;
TRUNCATE TABLE tag;
TRUNCATE TABLE resource;
TRUNCATE TABLE resource_category;
TRUNCATE TABLE sys_user;
TRUNCATE TABLE org;
SET FOREIGN_KEY_CHECKS = 1;


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
