-- ============================================================================
-- 红脉通 · 进阶 SQL：视图 / 存储过程 / 事务 / 触发器 / 全文索引
-- 文件：04_advanced.sql
-- 前提：先跑 01_schema.sql + 02_seed.sql（本文件基于那 16 张表和示例数据）
-- 执行：mysql -u root -p redmaitong < 04_advanced.sql
-- 注意：本文件有副作用（会新增/修改数据：审批一条申请、插入下载/浏览记录等），
--       建议在干净的种子数据上跑一次；想重跑就按 01→02→03→04 的顺序重来。
--
-- 演示路线（对应 README「阶段四」）：
--   1. 视图 VIEW       —— 把常用查询「存起来」，像表一样复用
--   2. 存储过程 PROCEDURE —— 带参数的 SQL 逻辑，能封装事务
--   3. 事务 TRANSACTION —— 多表操作要么全成要么全不成
--   4. 触发器 TRIGGER  —— 数据变化时自动执行一段逻辑
--   5. 全文索引 FULLTEXT —— 中文全文检索，对接首页搜索框
-- ============================================================================

USE redmaitong;

-- ============================================================================
-- 第 1 块：视图 VIEW —— 「存起来的查询」
--   视图不存数据，只存 SELECT 的定义；查询视图时实时执行那段 SELECT。
--   好处：把复杂的多表 JOIN 封装成一个"简化表"，前端/后端直接 SELECT 视图即可。
-- ============================================================================

-- 【1-1】资源详情视图：资源 + 机构名 + 二级分类 + 一级分类（一次 JOIN 三表）
DROP VIEW IF EXISTS v_resource_detail;
CREATE VIEW v_resource_detail AS
SELECT
  r.resource_id,
  r.title,
  o.org_name,
  c.category_name AS sub_category,      -- 二级分类
  p.category_name AS parent_category,   -- 一级分类
  r.share_level,
  r.view_count,
  r.download_count,
  r.audit_status,
  r.created_at
FROM resource r
INNER JOIN org o              ON o.org_id = r.org_id
INNER JOIN resource_category c ON c.category_id = r.category_id
LEFT  JOIN resource_category p ON p.category_id = c.parent_id;

-- 查询视图（和查普通表一模一样）
-- 预期：10 行，每行带 org_name / sub_category / parent_category
SELECT * FROM v_resource_detail LIMIT 5;

-- 【1-2】机构统计视图：把 03 里手写的 GROUP BY 封装起来
DROP VIEW IF EXISTS v_org_resource_stats;
CREATE VIEW v_org_resource_stats AS
SELECT
  o.org_id,
  o.org_name,
  COUNT(r.resource_id)                         AS resource_count,
  COALESCE(SUM(r.view_count), 0)               AS total_views,
  COALESCE(SUM(r.download_count), 0)           AS total_downloads
FROM org o
LEFT JOIN resource r ON r.org_id = o.org_id
GROUP BY o.org_id, o.org_name;

-- 预期：5 行（每家机构一行，resource_count 从 1 到 3）
SELECT * FROM v_org_resource_stats ORDER BY resource_count DESC;


-- ============================================================================
-- 第 2 块：存储过程 STORED PROCEDURE —— 「带参数的 SQL 逻辑」
--   注意：过程体里有分号，所以要用 DELIMITER 临时把「语句结束符」从 ; 换成 $$，
--   这样中间的分号不会被当成整段脚本的结束。
-- ============================================================================

-- 【2-1】查某机构收到的「待审批」申请（参数化查询）
DROP PROCEDURE IF EXISTS sp_pending_auth;
DELIMITER $$
CREATE PROCEDURE sp_pending_auth(IN p_org_id BIGINT UNSIGNED)
BEGIN
  SELECT
    s.auth_id,
    r.title,
    a.org_name AS apply_org,
    s.apply_purpose,
    s.created_at
  FROM share_auth s
  INNER JOIN resource r ON r.resource_id = s.resource_id
  INNER JOIN org a      ON a.org_id = s.apply_org_id
  WHERE s.target_org_id = p_org_id
    AND s.audit_status  = 0
  ORDER BY s.created_at DESC;
END$$
DELIMITER ;

-- 调用：查机构 2（革命纪念馆）收到的待审批申请
-- 预期：1 行（auth_id=1，高校马院申请煤油灯）
CALL sp_pending_auth(2);

-- 【2-2】审批共享申请：一个过程内「改状态 + 发通知 + 写日志」，用事务保证原子
DROP PROCEDURE IF EXISTS sp_approve_auth;
DELIMITER $$
CREATE PROCEDURE sp_approve_auth(
  IN p_auth_id BIGINT UNSIGNED,
  IN p_result  TINYINT,          -- 1 通过 / 2 驳回
  IN p_remark  VARCHAR(500)      -- 审批意见（可空）
)
BEGIN
  DECLARE v_resource_id   BIGINT UNSIGNED;
  DECLARE v_apply_user_id BIGINT UNSIGNED;
  DECLARE v_title         VARCHAR(200);

  -- 异常处理器：过程中任何一句 SQL 报错，自动回滚并返回提示
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SELECT '审批失败，已回滚' AS result;
  END;

  START TRANSACTION;

  -- 1) 查出申请对应的资源 ID 和申请人
  SELECT resource_id, apply_user_id
    INTO v_resource_id, v_apply_user_id
  FROM share_auth WHERE auth_id = p_auth_id;

  SELECT title INTO v_title FROM resource WHERE resource_id = v_resource_id;

  -- 2) 更新审批状态
  UPDATE share_auth
     SET audit_status = p_result,
         audit_remark = p_remark,
         audited_at   = NOW()
   WHERE auth_id = p_auth_id;

  -- 3) 给申请人发通知（申请人有账号才发）
  IF v_apply_user_id IS NOT NULL THEN
    INSERT INTO notification (user_id, type, title, content, is_read)
    VALUES (
      v_apply_user_id,
      'AUTH_AUDIT_RESULT',
      CONCAT('共享申请', IF(p_result = 1, '已通过', '已驳回')),
      CONCAT('您申请的《', v_title, '》', IF(p_result = 1, '已通过审批。', '被驳回。'),
             IF(p_remark IS NULL OR p_remark = '', '', CONCAT('审批意见：', p_remark))),
      0
    );
  END IF;

  -- 4) 写审计日志
  INSERT INTO operation_log (user_id, action, target_type, target_id, detail)
  VALUES (NULL, 'AUDIT', 'share_auth', p_auth_id,
          CONCAT('审批授权申请，结果=', p_result));

  COMMIT;
  SELECT '审批完成' AS result;
END$$
DELIMITER ;

-- 调用：审批 auth_id=1（高校马院申请煤油灯），通过
CALL sp_approve_auth(1, 1, '同意授权使用6个月');
-- 验证三步都发生了：状态已变 / 通知多一条 / 日志多一条
SELECT auth_id, audit_status, audit_remark, audited_at FROM share_auth WHERE auth_id = 1;
SELECT notification_id, user_id, title FROM notification ORDER BY notification_id DESC LIMIT 1;
SELECT COUNT(*) AS log_count FROM operation_log WHERE target_type = 'share_auth' AND target_id = 1;


-- ============================================================================
-- 第 3 块：事务 TRANSACTION —— 「多表操作要么全成、要么全不成」
--   「提交调取申请」其实要同时做三件事：写申请、通知资源方、写日志。
--   如果只成功两步就断电，数据就乱了。事务把这三步包成一个不可分割的整体。
-- ============================================================================

-- 【3-1】COMMIT 演示：三步全部提交
START TRANSACTION;

  -- ① 写调取申请（资源7 属于机构1 档案馆，申请方是机构4 高校马院）
  INSERT INTO share_auth (resource_id, apply_org_id, target_org_id, apply_user_id, apply_purpose, use_duration, contact_person, contact_phone, audit_status)
  VALUES (7, 4, 1, 4, '用于校内党史课程教学（事务演示）', '6_months', '陈老师', '13600136000', 0);
  SET @new_auth_id = LAST_INSERT_ID();   -- 拿到刚插入的 auth_id

  -- ② 通知资源方管理员（机构1 的张馆长 = user 2）
  INSERT INTO notification (user_id, type, title, content, is_read)
  VALUES (2, 'AUTH_AUDIT_RESULT', '收到新的共享申请', '高校马院向您申请调取《抗战时期军用物品三维数字模型集》，请及时审批。', 0);

  -- ③ 写操作日志
  INSERT INTO operation_log (user_id, action, target_type, target_id, detail)
  VALUES (4, 'APPLY', 'share_auth', @new_auth_id, '提交跨机构调取申请（事务演示）');

COMMIT;
SELECT '事务已提交，三步全部写入' AS result;
-- 验证：resource 7 现在有 1 条申请
SELECT auth_id, apply_org_id, target_org_id, audit_status FROM share_auth WHERE resource_id = 7;

-- 【3-2】ROLLBACK 演示：插入后回滚，等于什么都没发生
START TRANSACTION;
  INSERT INTO share_auth (resource_id, apply_org_id, target_org_id, apply_user_id, apply_purpose, use_duration, contact_person, contact_phone, audit_status)
  VALUES (6, 5, 2, NULL, '临时申请（演示回滚，不会真正入库）', '1_month', '刘主任', '13500135000', 0);
ROLLBACK;

-- 验证：resource 6 的申请数仍为 0（刚才那条被回滚掉了）
-- 预期：0
SELECT COUNT(*) AS resource6_auth_count FROM share_auth WHERE resource_id = 6;


-- ============================================================================
-- 第 4 块：触发器 TRIGGER —— 「数据变化时自动执行的钩子」
--   下载一次资源，download_count 就该 +1。与其让应用层记得更新，不如用触发器
--   让数据库自己维护。AFTER INSERT = 插入后触发；NEW 表示"刚插入的那一行"。
-- ============================================================================

-- 【4-1】下载记录插入后，自动给资源 download_count +1
DROP TRIGGER IF EXISTS trg_download_count;
DELIMITER $$
CREATE TRIGGER trg_download_count
AFTER INSERT ON download_record
FOR EACH ROW
BEGIN
  UPDATE resource
     SET download_count = download_count + 1
   WHERE resource_id = NEW.resource_id;
END$$
DELIMITER ;

-- 【4-2】浏览记录插入后，自动给资源 view_count +1
DROP TRIGGER IF EXISTS trg_browse_count;
DELIMITER $$
CREATE TRIGGER trg_browse_count
AFTER INSERT ON browse_history
FOR EACH ROW
BEGIN
  UPDATE resource
     SET view_count = view_count + 1
   WHERE resource_id = NEW.resource_id;
END$$
DELIMITER ;

-- 演示：resource 5 原来的 download_count 是 620
SELECT download_count AS before_download FROM resource WHERE resource_id = 5;
-- 插入一条下载记录（触发器自动 +1）
INSERT INTO download_record (user_id, resource_id, ip) VALUES (2, 5, '10.0.0.9');
-- 预期：变为 621
SELECT download_count AS after_download FROM resource WHERE resource_id = 5;

-- 演示：resource 5 原来的 view_count 是 4210，插入浏览记录后应为 4211
SELECT view_count AS before_view FROM resource WHERE resource_id = 5;
INSERT INTO browse_history (user_id, resource_id) VALUES (2, 5);
SELECT view_count AS after_view FROM resource WHERE resource_id = 5;


-- ============================================================================
-- 第 5 块：全文索引 FULLTEXT —— 「对接首页搜索框」
--   LIKE '%xx%' 无法走普通索引，数据多了就是全表扫。
--   全文索引为「关键词检索」而生，支持中文分词（ngram）和相关度评分。
--   注意：ngram 是 MySQL 内置的中文分词器，默认按 2 个字切词（ngram_token_size=2）。
-- ============================================================================

-- 给 resource 的 title + meta_desc 建全文索引（用 ngram 中文分词器）
ALTER TABLE resource ADD FULLTEXT INDEX ft_resource_search (title, meta_desc) WITH PARSER ngram;
-- 若重复执行本文件报 "Duplicate key name 'ft_resource_search'"，先手动删掉再建：
--   ALTER TABLE resource DROP INDEX ft_resource_search;

-- 中文全文检索：搜「长征」
-- 预期：命中 resource 2、9（标题都含"长征"），并按相关度降序
SELECT
  resource_id,
  title,
  MATCH(title, meta_desc) AGAINST('长征' IN NATURAL LANGUAGE MODE) AS relevance
FROM resource
WHERE MATCH(title, meta_desc) AGAINST('长征' IN NATURAL LANGUAGE MODE)
ORDER BY relevance DESC;

-- 对比：同样的需求用 LIKE 做（体会为什么 LIKE 慢、且没有相关度）
SELECT resource_id, title
FROM resource
WHERE title LIKE '%长征%' OR meta_desc LIKE '%长征%';

-- 全文检索 + 布尔模式（支持 +必须 / -排除 语法，进阶可玩）
-- 例：含"长征"但不含"教学"的资源
SELECT resource_id, title
FROM resource
WHERE MATCH(title, meta_desc) AGAINST('+长征 -教学' IN BOOLEAN MODE);
