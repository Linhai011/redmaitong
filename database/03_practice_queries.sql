-- ============================================================================
-- 红脉通 · 分层演示查询
-- 文件：03_practice_queries.sql
-- 作用：由易到难，覆盖 SELECT → 聚合 → JOIN → 子查询 → 窗口函数 → EXPLAIN
-- 执行：mysql -u root -p redmaitong < 03_practice_queries.sql
-- ============================================================================

USE redmaitong;

-- ============================================================================
-- 第 1 ：基础 SELECT —— WHERE / ORDER BY / LIMIT / LIKE
-- ============================================================================

-- 【1-1】查询所有「已认证入驻」的机构（status = 1）
-- 演示：SELECT 列 + WHERE 条件 + 关系比较
-- 预期：返回 4 行（org_id = 1/2/3/5，高校马院 status=0 不出现）
SELECT org_id, org_name, org_type, status
FROM org
WHERE status = 1;

-- 【1-2】模糊查询：标题里包含「长征」的资源
-- 演示：LIKE + 通配符 %（% 匹配任意长度）
-- 预期：返回 2 行（resource_id = 2 和 9）
SELECT resource_id, title
FROM resource
WHERE title LIKE '%长征%';

-- 【1-3】查询浏览数超过 10000 的资源，按浏览数从高到低排序
-- 演示：ORDER BY ... DESC 降序（ASC 是升序，默认）
-- 预期：2 行，顺序为 resource_id=3(27500) 在前，1(13620) 在后
SELECT resource_id, title, view_count
FROM resource
WHERE view_count > 10000
ORDER BY view_count DESC;

-- 【1-4】查询「待审核」的资源（audit_status = 0），只取前 1 条
-- 演示：LIMIT 限制返回行数
-- 预期：返回 1 行 resource_id=10（某地革命旧址VR全景漫游）
SELECT resource_id, title, audit_status
FROM resource
WHERE audit_status = 0
LIMIT 1;


-- ============================================================================
-- 第 2 ：聚合函数 —— COUNT / SUM / AVG / GROUP BY / HAVING
-- ============================================================================

-- 【2-1】统计每家机构的资源数量（多表联查版，先 JOIN 再分组）
-- 演示：GROUP BY 分组 + COUNT 计数 + JOIN 取机构名
-- 预期：5 行，org2=3 份最多，org5=1 份最少
SELECT o.org_name, COUNT(r.resource_id) AS res_count
FROM org o
LEFT JOIN resource r ON r.org_id = o.org_id
GROUP BY o.org_id, o.org_name
ORDER BY res_count DESC;

-- 【2-2】统计各共享等级的资源数量
-- 演示：CASE 把数字编码转成可读文字，再分组
-- 预期：2 行（1级完全公开=4 份，2级授权访问=6 份）
SELECT
  CASE share_level
    WHEN 1 THEN '1级 完全公开'
    WHEN 2 THEN '2级 授权访问'
    WHEN 3 THEN '3级 机构内部'
  END AS share_level_name,
  COUNT(*) AS cnt
FROM resource
GROUP BY share_level;

-- 【2-3】整体统计：资源总数、浏览总数、平均浏览数
-- 演示：COUNT / SUM / AVG 三个最常用聚合函数
-- 预期：总资源 10，浏览总数 83500，平均浏览 8350
SELECT
  COUNT(*)              AS total_resources,
  SUM(view_count)       AS total_views,
  AVG(view_count)       AS avg_views
FROM resource;

-- 【2-4】只保留资源数 >= 2 的机构
-- 演示：HAVING 对「分组后的结果」过滤（WHERE 是分组前过滤，两者区别要分清）
-- 预期：4 行（org1=2 / org2=3 / org3=2 / org4=2），org5=1 被 HAVING 淘汰
SELECT o.org_name, COUNT(r.resource_id) AS res_count
FROM org o
LEFT JOIN resource r ON r.org_id = o.org_id
GROUP BY o.org_id, o.org_name
HAVING res_count >= 2
ORDER BY res_count DESC;


-- ============================================================================
-- 第 3 ：JOIN 连接 —— INNER / LEFT / 自连接
-- ============================================================================

-- 【3-1】三表内连接：资源 + 机构名 + 二级分类名
-- 演示：INNER JOIN（只保留两边都能匹配上的行），这里 resource 是中心
-- 预期：10 行，每行带 org_name 和 category_name
SELECT r.resource_id, r.title, o.org_name, c.category_name, r.share_level
FROM resource r
INNER JOIN org o              ON o.org_id = r.org_id
INNER JOIN resource_category c ON c.category_id = r.category_id
ORDER BY r.resource_id;

-- 【3-2】查某个资源挂的所有标签（resource 2 长征器具）
-- 演示：通过中间表 resource_tag 把 resource 和 tag 连起来（多对多）
-- 预期：3 行，标签名为 长征 / 3D模型 / 文物
SELECT r.title, t.tag_name
FROM resource r
INNER JOIN resource_tag rt ON rt.resource_id = r.resource_id
INNER JOIN tag t           ON t.tag_id = rt.tag_id
WHERE r.resource_id = 2;

-- 【3-3】左连接：所有机构 + 各自用户数（含 0 个用户的机构）
-- 演示：LEFT JOIN 会保留左表（org）所有行，右表没匹配就填 NULL
-- 预期：5 行，org3 党史研究室、org5 文旅基地 的 user_count = 0（它们没有用户）
SELECT o.org_name, COUNT(u.user_id) AS user_count
FROM org o
LEFT JOIN sys_user u ON u.org_id = o.org_id
GROUP BY o.org_id, o.org_name
ORDER BY o.org_id;

-- 【3-4】自连接：列出每个二级分类及其所属一级分类
-- 演示：一张表自己连自己（resource_category.parent_id 指向本表）
-- 预期：17 行（所有二级分类），每行带 parent_name
SELECT child.category_name  AS sub_name,
       parent.category_name AS parent_name
FROM resource_category child
LEFT JOIN resource_category parent ON parent.category_id = child.parent_id
WHERE child.level = 2
ORDER BY parent.category_id, child.sort_order;


-- ============================================================================
-- 第 4 ：子查询 —— 标量子查询 / IN / EXISTS
-- ============================================================================

-- 【4-1】查询浏览数高于全平台平均值的资源
-- 演示：标量子查询（括号里的 SELECT 只返回一个值，这里是平均浏览数 8350）
-- 预期：3 行（resource_id=1/2/3，浏览数都 > 8350）
SELECT resource_id, title, view_count
FROM resource
WHERE view_count > (SELECT AVG(view_count) FROM resource)
ORDER BY view_count DESC;

-- 【4-2】查询「被申请过跨机构调取」的资源标题
-- 演示：IN + 子查询（子查询返回一列，外层判断是否在这一列里）
-- 预期：3 行（resource_id = 1/4/9，正是 share_auth 表里出现过的）
SELECT resource_id, title
FROM resource
WHERE resource_id IN (SELECT resource_id FROM share_auth)
ORDER BY resource_id;

-- 【4-3】查询「收到过其他机构调取申请」的机构
-- 演示：EXISTS（只要子查询有任意一行就为真，比 IN 更适合"存在性"判断）
-- 预期：3 行（org1/2/3，它们出现在 share_auth 的 target_org_id 里）
SELECT o.org_id, o.org_name
FROM org o
WHERE EXISTS (
  SELECT 1 FROM share_auth s WHERE s.target_org_id = o.org_id
);


-- ============================================================================
-- 第 5 ：窗口函数（MySQL 8.0 特性，进阶）
-- ============================================================================

-- 【5-1】给所有资源按浏览数做全局排名（ROW_NUMBER 不并列）
-- 演示：ROW_NUMBER() OVER (ORDER BY ...) —— 每条一个不重复的序号
-- 预期：10 行，rn=1 是 resource 3(27500)，rn=10 是 resource 10(1980)
SELECT
  ROW_NUMBER() OVER (ORDER BY view_count DESC) AS rn,
  resource_id, title, view_count
FROM resource;

-- 【5-2】每个机构内部按浏览数排名（PARTITION BY 分组后各自排名）
-- 演示：OVER (PARTITION BY ...) —— 按机构分组，组内再排序排名
-- 预期：org2 组内有 rn=1/2/3，其余机构组内各有 rn=1/2
SELECT
  o.org_name,
  ROW_NUMBER() OVER (PARTITION BY r.org_id ORDER BY r.view_count DESC) AS org_rank,
  r.title, r.view_count
FROM resource r
INNER JOIN org o ON o.org_id = r.org_id
ORDER BY r.org_id, org_rank;

-- 【5-3】同时显示每家机构资源数 + 全平台资源总数（聚合窗口函数）
-- 演示：聚合函数也能开窗，OVER () 表示在整个结果集上计算
-- 预期：5 行，org_count 是各机构数，total_all 恒为 10
SELECT
  o.org_name,
  COUNT(*) OVER (PARTITION BY r.org_id) AS org_count,
  COUNT(*) OVER ()                       AS total_all
FROM resource r
INNER JOIN org o ON o.org_id = r.org_id
GROUP BY r.org_id, o.org_name
ORDER BY r.org_id;


-- ============================================================================
-- 第 6 ：索引与执行计划（EXPLAIN 入门）
-- ============================================================================

-- 【6-1】看「按机构查资源」这条高频查询有没有走索引
-- 演示：EXPLAIN 显示优化器怎么执行；重点看 type / possible_keys / key 三列
-- 预期：key 列应显示 idx_resource_org（说明用上了我们建的索引）
EXPLAIN
SELECT resource_id, title
FROM resource
WHERE org_id = 2;

-- 【6-2】对比：对未建索引的列（如 resource_year）做等值查询
-- 演示：没索引时 type 可能是 ALL（全表扫描），体会"建索引的意义"
-- 预期：type 为 ALL，rows 接近 10（全表扫描）
EXPLAIN
SELECT resource_id, title
FROM resource
WHERE resource_year = '1930-1949';

-- 【6-3】查看 resource 表当前有哪些索引
-- 演示：SHOW INDEX 列出表上的所有索引（主键、唯一、普通）
-- 预期：能看到 PRIMARY 和 idx_resource_org / idx_resource_category 等
SHOW INDEX FROM resource;
