-- 20260922163200_restrict_meal_delivery_order_read
--
-- 背景
-- ----
-- meal_delivery_order 原有 SELECT 策略为 "Enable read access for all users"：
--     FOR SELECT TO public USING (true)
-- 即任何持有 anon key 的人都能读取全表。anon key 内置于 Flutter 包
-- （lib/core/config/env.dart），因此下列字段对公网完全可读：
--     recipient_name / phone / province / city / district /
--     detailed_address / longitude / latitude
-- 这是一处正在发生的客户 PII 泄露。
--
-- 本迁移把读取范围收敛为「订单所有者」与「归属商家」。
--
-- 影响面（已在生产库只读验证）
-- --------------------------
--   * 全表 3126 行，其中 0 行属于「无 owner」的孤儿单 → 不会出现无人可见的数据。
--   * recipe_order 中 user_id 为 NULL 的行数为 0 → 无历史脏数据被锁死。
--   * 模拟 JWT 验证结果：
--       匿名                → 0 行
--       订单所有者（样本）  → 3057 行（自己的单）
--       归属商家（样本）    → 1992 行（该商家的单）
--       其他普通用户        → 3 行（仅自己的单）
--   * 依赖索引均已存在，策略子查询走主键/外键索引，无全表扫描风险：
--       recipe_order_pkey(id)、idx_recipe_order_user(user_id)、
--       idx_meal_delivery_recipe_order(recipe_order_id)、merchant_pkey(id)
--
-- 客户端读取路径（已核对，全部按当前用户的 recipe_order 过滤，不受影响）
-- ---------------------------------------------------------------------
--   lib/features/order/data/order_repository.dart:106  select ... eq('recipe_order_id', ...)
--   lib/features/order/data/order_repository.dart:140  select ... inFilter('recipe_order_id', ...)
--   （同文件 221 / 348 行为 update，走既有 UPDATE 策略，本迁移不涉及）
--
-- 注意事项
-- --------
--   * service_role 绕过 RLS，因此后续的快递100 回调边缘函数（service_role 写库）不受影响。
--   * create-order 边缘函数用用户 JWT 执行 insert(...).select()，RETURNING 需同时满足
--     SELECT 策略；此时 recipe_order 已插入且 user_id = auth.uid()，策略成立，故不受影响。
--   * 若将来新增「商家端」或「客服后台」读取配送单，需要相应扩展本策略，
--     不要退回 USING (true)。

-- 1) 移除全开策略
drop policy if exists "Enable read access for all users" on public.meal_delivery_order;

-- 2) 仅订单所有者与归属商家可读
--    用 exists 而非 IN：避免 merchant_id 为 NULL 时的三值逻辑意外；
--    anon 的 auth.uid() 为 NULL，两个 exists 均不成立，匿名读被完全关闭。
create policy "配送单仅订单所有者与归属商家可读"
  on public.meal_delivery_order
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.recipe_order ro
      where ro.id = meal_delivery_order.recipe_order_id
        and ro.user_id = auth.uid()
    )
    or exists (
      select 1
      from public.merchant m
      where m.id = meal_delivery_order.merchant_id
        and m.user_id = auth.uid()
    )
  );
