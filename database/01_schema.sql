-- ============================================================================
-- 红脉通 · 红色数字资源开放共享平台 数据库结构
-- 文件：01_schema.sql
-- 作用：建库 + 建全部 16 张表（含字段注释、主键、外键、索引、CHECK 约束）
-- 适用：MySQL 8.0
-- 执行：mysql -u root -p < 01_schema.sql   （或在 Navicat/Workbench 里直接运行）
--
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 第 0 步：建库。IF NOT EXISTS 表示"存在就跳过"，可重复执行。
-- ----------------------------------------------------------------------------
DROP DATABASE IF EXISTS redmaitong;
CREATE DATABASE redmaitong
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE redmaitong;

-- 统一关闭外键检查，方便按任意顺序重跑（最后再打开）
SET FOREIGN_KEY_CHECKS = 0;


-- ============================================================================
-- 1. org —— 机构表（入驻平台的所有协同机构）
--    「一对多」的"一"端：一个机构名下可以有多个用户、多份资源
-- ============================================================================
DROP TABLE IF EXISTS org;
CREATE TABLE org (
  org_id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '机构ID（代理主键）',
  org_name        VARCHAR(100)    NOT NULL                COMMENT '机构全称',
  org_type        VARCHAR(10)     NOT NULL                COMMENT '机构类型代码：ARCH档案馆/MEM纪念馆/HIST党史研究室/MARX高校马院/CULT文旅基地',
  credit_code     VARCHAR(18)     DEFAULT NULL            COMMENT '统一社会信用代码（18位，唯一）',
  address         VARCHAR(200)    DEFAULT NULL            COMMENT '机构地址',
  contact_name    VARCHAR(50)     DEFAULT NULL            COMMENT '对接负责人姓名',
  contact_phone   VARCHAR(11)     DEFAULT NULL            COMMENT '联系电话',
  email           VARCHAR(100)    DEFAULT NULL            COMMENT '机构邮箱',
  description     TEXT                                    COMMENT '机构简介',
  apply_reason    TEXT                                    COMMENT '入驻申请理由（仅审核时填写）',
  cert_file_path  VARCHAR(500)    DEFAULT NULL            COMMENT '资质证明文件路径',
  api_level       TINYINT         NOT NULL DEFAULT 1      COMMENT 'API权限等级：1基础版 2完整版',
  status          TINYINT         NOT NULL DEFAULT 0      COMMENT '状态：0待审核 1已认证入驻 2已禁用',
  created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                  ON UPDATE CURRENT_TIMESTAMP             COMMENT '更新时间（自动维护）',
  PRIMARY KEY (org_id),
  UNIQUE KEY uk_org_credit_code (credit_code),            -- 信用代码唯一，防止重复入驻
  KEY idx_org_type (org_type),                            -- 按类型筛选用
  KEY idx_org_status (status)                             -- 按审核状态筛选用
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='协同机构表';


-- ============================================================================
-- 2. sys_user —— 用户表
--    「多对一」的"多"端：多个用户可能属于同一家机构（个人用户的 org_id 为 NULL）
--    注意：表名用 sys_user 而不是 user，避免和 MySQL 自带的 mysql.user 混淆
-- ============================================================================
DROP TABLE IF EXISTS sys_user;
CREATE TABLE sys_user (
  user_id        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '用户ID（代理主键）',
  username       VARCHAR(50)     NOT NULL                COMMENT '登录账号（唯一）',
  password_hash  VARCHAR(100)    NOT NULL                COMMENT '密码哈希（bcrypt 加密后存这里，绝不存明文）',
  phone          VARCHAR(11)     DEFAULT NULL            COMMENT '手机号（唯一，可空）',
  email          VARCHAR(100)    DEFAULT NULL            COMMENT '邮箱',
  role           VARCHAR(20)     NOT NULL DEFAULT 'INDIVIDUAL'
                 COMMENT '角色：PLATFORM_ADMIN平台管理员 / ORG_ADMIN机构管理员 / ORG_USER机构普通用户 / INDIVIDUAL个人用户',
  org_id         BIGINT UNSIGNED DEFAULT NULL            COMMENT '所属机构ID（机构用户才有，个人用户为NULL）',
  status         TINYINT         NOT NULL DEFAULT 1      COMMENT '状态：1启用 0禁用',
  created_at     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '注册时间',
  updated_at     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                 ON UPDATE CURRENT_TIMESTAMP             COMMENT '更新时间',
  PRIMARY KEY (user_id),
  UNIQUE KEY uk_user_username (username),
  UNIQUE KEY uk_user_phone (phone),
  KEY idx_user_org (org_id),                             -- 查"某机构下所有用户"用
  KEY idx_user_role (role),
  CONSTRAINT fk_user_org FOREIGN KEY (org_id) REFERENCES org (org_id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户表';


-- ============================================================================
-- 3. resource_category —— 资源分类目录表（自关联，表达「一级 / 二级」两级分类）
--    自关联：parent_id 指向本表自己的另一行。parent_id 为 NULL 的行 = 一级分类
--    一级分类 6 个（党史文献档案 / 革命文物3D图像 / 红色影像视频 / 口述历史音频 / 红色教研素材 / 旧址全景VR）
--    每个一级分类下挂若干二级分类（见需求文档附录 A）
-- ============================================================================
DROP TABLE IF EXISTS resource_category;
CREATE TABLE resource_category (
  category_id    BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '分类ID',
  category_name  VARCHAR(50)     NOT NULL                COMMENT '分类名称',
  parent_id      BIGINT UNSIGNED DEFAULT NULL            COMMENT '父分类ID（NULL=一级分类，否则=所属一级分类）',
  level          TINYINT         NOT NULL                COMMENT '层级：1一级 2二级',
  sort_order     INT             NOT NULL DEFAULT 0      COMMENT '排序号，越小越靠前',
  PRIMARY KEY (category_id),
  KEY idx_category_parent (parent_id),
  CONSTRAINT fk_category_parent FOREIGN KEY (parent_id) REFERENCES resource_category (category_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='资源分类目录表（自关联）';


-- ============================================================================
-- 4. resource —— 资源表（核心业务表，体量最大的一张）
--    一个资源属于一个机构（org）、一个分类（category）；文件另存 resource_file 表
-- ============================================================================
DROP TABLE IF EXISTS resource;
CREATE TABLE resource (
  resource_id     BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '资源ID（代理主键）',
  title           VARCHAR(200)    NOT NULL                COMMENT '资源标准标题',
  category_id     BIGINT UNSIGNED NOT NULL                COMMENT '资源分类ID（二级分类，指向 resource_category）',
  org_id          BIGINT UNSIGNED NOT NULL                COMMENT '来源机构ID（资源归属，指向 org）',
  meta_desc       TEXT                                    COMMENT '元数据描述（历史背景/人物/事件）',
  resource_year   VARCHAR(20)     DEFAULT NULL            COMMENT '资源年代标签，如 1930-1949',
  share_level     TINYINT         NOT NULL DEFAULT 2      COMMENT '共享等级：1完全公开 2授权访问 3机构内部',
  cover_url       VARCHAR(500)    DEFAULT NULL            COMMENT '封面图URL',
  view_count      INT UNSIGNED    NOT NULL DEFAULT 0      COMMENT '浏览次数',
  download_count  INT UNSIGNED    NOT NULL DEFAULT 0      COMMENT '下载次数',
  audit_status    TINYINT         NOT NULL DEFAULT 0      COMMENT '审核状态：0待审核 1已发布 2已驳回 3已下架',
  created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                  ON UPDATE CURRENT_TIMESTAMP             COMMENT '更新时间',
  PRIMARY KEY (resource_id),
  KEY idx_resource_org (org_id),                          -- 高频：按机构查资源
  KEY idx_resource_category (category_id),                -- 高频：按分类查资源
  KEY idx_resource_share (share_level),                   -- 高频：按共享等级筛选
  KEY idx_resource_audit (audit_status),                  -- 高频：审核列表
  CONSTRAINT fk_resource_category FOREIGN KEY (category_id) REFERENCES resource_category (category_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,                 -- 有资源引用时不允许删分类
  CONSTRAINT fk_resource_org FOREIGN KEY (org_id) REFERENCES org (org_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  -- MySQL 8.0 的 CHECK 约束：让数据库层面强制 share_level 只能取 1/2/3
  CONSTRAINT chk_resource_share_level CHECK (share_level BETWEEN 1 AND 3)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='数字资源表';


-- ============================================================================
-- 5. tag —— 标签表（多对多关系的一侧）
-- ============================================================================
DROP TABLE IF EXISTS tag;
CREATE TABLE tag (
  tag_id     BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '标签ID',
  tag_name   VARCHAR(50)     NOT NULL                COMMENT '标签名（唯一）',
  PRIMARY KEY (tag_id),
  UNIQUE KEY uk_tag_name (tag_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='标签表';


-- ============================================================================
-- 6. resource_tag —— 资源-标签关联表（多对多的「中间表」）
--     这是把原需求文档里 resource.tags 那个「逗号分隔字符串」拆出来的结果。
--     复合主键 (resource_id, tag_id) 保证同一个资源不会重复挂同一个标签。
-- ============================================================================
DROP TABLE IF EXISTS resource_tag;
CREATE TABLE resource_tag (
  resource_id  BIGINT UNSIGNED NOT NULL COMMENT '资源ID',
  tag_id       BIGINT UNSIGNED NOT NULL COMMENT '标签ID',
  PRIMARY KEY (resource_id, tag_id),
  KEY idx_rt_tag (tag_id),                               -- 反向：查"某标签下所有资源"
  CONSTRAINT fk_rt_resource FOREIGN KEY (resource_id) REFERENCES resource (resource_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_rt_tag FOREIGN KEY (tag_id) REFERENCES tag (tag_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='资源-标签关联表';


-- ============================================================================
-- 7. resource_file —— 资源文件表（一对多：一个资源可以有多个文件）
--     原型上传表单明确「支持批量上传」，所以文件从 resource 里拆出来单独存
-- ============================================================================
DROP TABLE IF EXISTS resource_file;
CREATE TABLE resource_file (
  file_id      BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '文件ID',
  resource_id  BIGINT UNSIGNED NOT NULL                COMMENT '所属资源ID',
  file_name    VARCHAR(200)    DEFAULT NULL            COMMENT '原始文件名',
  file_path    VARCHAR(500)    NOT NULL                COMMENT '文件存储路径/URL',
  file_size    BIGINT UNSIGNED DEFAULT NULL            COMMENT '文件大小（字节）',
  file_type    VARCHAR(20)     DEFAULT NULL            COMMENT '文件类型：pdf/mp4/mp3/glb/jpg/png',
  sort_order   INT             NOT NULL DEFAULT 0      COMMENT '排序号',
  PRIMARY KEY (file_id),
  KEY idx_file_resource (resource_id),
  CONSTRAINT fk_file_resource FOREIGN KEY (resource_id) REFERENCES resource (resource_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='资源文件表';


-- ============================================================================
-- 8. share_auth —— 共享授权申请表
--     跨机构调取的完整闭环：申请机构(apply_org) 向 资源所属机构(target_org) 申请某资源
--     apply_org_id 和 target_org_id 都指向 org 表 —— 同表双外键，值得体会
-- ============================================================================
DROP TABLE IF EXISTS share_auth;
CREATE TABLE share_auth (
  auth_id        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '授权申请ID（代理主键）',
  resource_id    BIGINT UNSIGNED NOT NULL                COMMENT '目标资源ID',
  apply_org_id   BIGINT UNSIGNED NOT NULL                COMMENT '申请机构ID',
  target_org_id  BIGINT UNSIGNED NOT NULL                COMMENT '资源所属机构ID',
  apply_user_id  BIGINT UNSIGNED DEFAULT NULL            COMMENT '发起申请的用户ID',
  apply_purpose  TEXT            NOT NULL                COMMENT '申请用途说明',
  use_duration   VARCHAR(20)     DEFAULT NULL            COMMENT '使用期限：1_month/3_months/6_months/1_year/long_term',
  contact_person VARCHAR(50)     DEFAULT NULL            COMMENT '联系人姓名',
  contact_phone  VARCHAR(11)     DEFAULT NULL            COMMENT '联系电话',
  audit_status   TINYINT         NOT NULL DEFAULT 0      COMMENT '审批状态：0待审批 1已通过 2已驳回 3已过期',
  audit_result   TEXT                                    COMMENT '审批结果说明',
  audit_remark   VARCHAR(500)    DEFAULT NULL            COMMENT '审批意见',
  audited_at     DATETIME        DEFAULT NULL            COMMENT '审批时间',
  created_at     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '申请时间',
  PRIMARY KEY (auth_id),
  KEY idx_auth_resource (resource_id),
  KEY idx_auth_apply_org (apply_org_id),
  KEY idx_auth_target_org (target_org_id),
  KEY idx_auth_status (audit_status),                    -- 待审批列表高频筛选
  CONSTRAINT fk_auth_resource FOREIGN KEY (resource_id) REFERENCES resource (resource_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_auth_apply_org FOREIGN KEY (apply_org_id) REFERENCES org (org_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_auth_target_org FOREIGN KEY (target_org_id) REFERENCES org (org_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_auth_user FOREIGN KEY (apply_user_id) REFERENCES sys_user (user_id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='共享授权申请表';


-- ============================================================================
-- 9. exhibition —— 数字展馆表（联合专题展馆的主表）
--     参与机构和展品资源分别用下面两张关联表表达「多对多」
-- ============================================================================
DROP TABLE IF EXISTS exhibition;
CREATE TABLE exhibition (
  exhibition_id    BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '展馆ID',
  exhibition_name  VARCHAR(200)    NOT NULL                COMMENT '展馆名称',
  description      TEXT                                    COMMENT '展馆描述',
  cover_url        VARCHAR(500)    DEFAULT NULL            COMMENT '封面图URL',
  status           TINYINT         NOT NULL DEFAULT 0      COMMENT '发布状态：0草稿 1已发布 2已下架',
  created_at       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  published_at     DATETIME        DEFAULT NULL            COMMENT '发布时间',
  PRIMARY KEY (exhibition_id),
  KEY idx_exhibition_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='数字展馆表';


-- ============================================================================
-- 10. exhibition_org —— 展馆-机构关联表（多对多）
--     原需求文档里 exhibition.orgIds 是「逗号分隔的机构ID列表」——典型的反面教材。
--     这里拆成中间表，一行 = 一个展馆参与的一家机构。
-- ============================================================================
DROP TABLE IF EXISTS exhibition_org;
CREATE TABLE exhibition_org (
  exhibition_id  BIGINT UNSIGNED NOT NULL COMMENT '展馆ID',
  org_id         BIGINT UNSIGNED NOT NULL COMMENT '参与机构ID',
  PRIMARY KEY (exhibition_id, org_id),
  KEY idx_eo_org (org_id),
  CONSTRAINT fk_eo_exhibition FOREIGN KEY (exhibition_id) REFERENCES exhibition (exhibition_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_eo_org FOREIGN KEY (org_id) REFERENCES org (org_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='展馆-机构关联表';


-- ============================================================================
-- 11. exhibition_resource —— 展馆-资源关联表（多对多，展品）
-- ============================================================================
DROP TABLE IF EXISTS exhibition_resource;
CREATE TABLE exhibition_resource (
  exhibition_id  BIGINT UNSIGNED NOT NULL COMMENT '展馆ID',
  resource_id    BIGINT UNSIGNED NOT NULL COMMENT '展品资源ID',
  sort_order     INT             NOT NULL DEFAULT 0      COMMENT '展品排序',
  PRIMARY KEY (exhibition_id, resource_id),
  KEY idx_er_resource (resource_id),
  CONSTRAINT fk_er_exhibition FOREIGN KEY (exhibition_id) REFERENCES exhibition (exhibition_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_er_resource FOREIGN KEY (resource_id) REFERENCES resource (resource_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='展馆-资源关联表';


-- ============================================================================
-- 12. favorite —— 收藏表（对应个人中心「我的收藏」）
--     唯一键 (user_id, resource_id) 防止重复收藏
-- ============================================================================
DROP TABLE IF EXISTS favorite;
CREATE TABLE favorite (
  favorite_id  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '收藏ID',
  user_id      BIGINT UNSIGNED NOT NULL                COMMENT '用户ID',
  resource_id  BIGINT UNSIGNED NOT NULL                COMMENT '资源ID',
  created_at   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '收藏时间',
  PRIMARY KEY (favorite_id),
  UNIQUE KEY uk_fav_user_resource (user_id, resource_id),
  KEY idx_fav_resource (resource_id),
  CONSTRAINT fk_fav_user FOREIGN KEY (user_id) REFERENCES sys_user (user_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_fav_resource FOREIGN KEY (resource_id) REFERENCES resource (resource_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='收藏表';


-- ============================================================================
-- 13. download_record —— 下载记录表（对应个人中心「下载记录」）
-- ============================================================================
DROP TABLE IF EXISTS download_record;
CREATE TABLE download_record (
  download_id  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '下载记录ID',
  user_id      BIGINT UNSIGNED NOT NULL                COMMENT '下载用户ID',
  resource_id  BIGINT UNSIGNED NOT NULL                COMMENT '下载资源ID',
  ip           VARCHAR(45)     DEFAULT NULL            COMMENT '下载来源IP',
  created_at   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '下载时间',
  PRIMARY KEY (download_id),
  KEY idx_dl_user (user_id),
  KEY idx_dl_resource (resource_id),
  CONSTRAINT fk_dl_user FOREIGN KEY (user_id) REFERENCES sys_user (user_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_dl_resource FOREIGN KEY (resource_id) REFERENCES resource (resource_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='下载记录表';


-- ============================================================================
-- 14. browse_history —— 浏览历史表（对应个人中心「浏览历史」）
-- ============================================================================
DROP TABLE IF EXISTS browse_history;
CREATE TABLE browse_history (
  history_id   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '浏览记录ID',
  user_id      BIGINT UNSIGNED NOT NULL                COMMENT '用户ID',
  resource_id  BIGINT UNSIGNED NOT NULL                COMMENT '浏览资源ID',
  created_at   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '浏览时间',
  PRIMARY KEY (history_id),
  KEY idx_bh_user (user_id),
  KEY idx_bh_resource (resource_id),
  CONSTRAINT fk_bh_user FOREIGN KEY (user_id) REFERENCES sys_user (user_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_bh_resource FOREIGN KEY (resource_id) REFERENCES resource (resource_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='浏览历史表';


-- ============================================================================
-- 15. notification —— 通知表（对应 WebSocket 实时通知）
-- ============================================================================
DROP TABLE IF EXISTS notification;
CREATE TABLE notification (
  notification_id  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '通知ID',
  user_id          BIGINT UNSIGNED NOT NULL                COMMENT '接收用户ID',
  type             VARCHAR(30)     NOT NULL                COMMENT '类型：AUTH_AUDIT_RESULT/RESOURCE_AUDIT_RESULT/EXHIBITION_INVITE/SYSTEM_NOTICE',
  title            VARCHAR(200)    NOT NULL                COMMENT '通知标题',
  content          TEXT                                    COMMENT '通知内容',
  is_read          TINYINT         NOT NULL DEFAULT 0      COMMENT '是否已读：0未读 1已读',
  created_at       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '发送时间',
  PRIMARY KEY (notification_id),
  KEY idx_ntf_user (user_id),
  KEY idx_ntf_user_read (user_id, is_read),                -- 组合索引：查"某用户未读通知"
  CONSTRAINT fk_ntf_user FOREIGN KEY (user_id) REFERENCES sys_user (user_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='通知表';


-- ============================================================================
-- 16. operation_log —— 操作日志表（审计追溯，对应需求 SE-005）
-- ============================================================================
DROP TABLE IF EXISTS operation_log;
CREATE TABLE operation_log (
  log_id       BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '日志ID',
  user_id      BIGINT UNSIGNED DEFAULT NULL            COMMENT '操作用户ID（可空，未登录操作也记录）',
  action       VARCHAR(50)     NOT NULL                COMMENT '操作类型：LOGIN/UPLOAD/DOWNLOAD/AUDIT/...',
  target_type  VARCHAR(30)     DEFAULT NULL            COMMENT '操作对象类型：resource/org/share_auth/...',
  target_id    BIGINT UNSIGNED DEFAULT NULL            COMMENT '操作对象ID',
  detail       TEXT                                    COMMENT '操作详情',
  ip           VARCHAR(45)     DEFAULT NULL            COMMENT '操作来源IP',
  created_at   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '操作时间',
  PRIMARY KEY (log_id),
  KEY idx_log_user (user_id),
  KEY idx_log_action (action),
  KEY idx_log_created (created_at),
  CONSTRAINT fk_log_user FOREIGN KEY (user_id) REFERENCES sys_user (user_id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='操作日志表';


-- 恢复外键检查
SET FOREIGN_KEY_CHECKS = 1;

-- 建表完成，自检：
-- SHOW TABLES;          -> 应看到 16 张表
-- DESC resource;        -> 应看到 category_id/org_id 两列的 Key 列为 MUL（外键/索引标记）
