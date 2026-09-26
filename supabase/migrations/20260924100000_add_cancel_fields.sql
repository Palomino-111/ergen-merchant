-- 20260924100000_add_cancel_fields
--
-- 为「取消第三方同城配送订单」（快递100 同城急送 取消接口）补落库字段。
--
-- 背景
-- ----
--   supabase/functions/cancel-delivery-order 调用快递100 method=cancel 后，
--   需要把两样东西记下来，而 20260922170000 里**刻意没有**加这两列
--   （原文：「未加 cancel_fee：取消流程尚未实现，无任何代码写入该列，等做取消时再加」）。
--   现在取消流程实现了，按当时的约定补上。
--
-- 为什么要单独记 cancel_fee
-- ------------------------
--   取消可能产生费用（快递100 文档第 3 节：「注意可能产生费用」），
--   返回的 cancelFee 是我方**真实支出**。
--   不能拿 provider_fee 复用：provider_fee 是这一单的配送费，cancel_fee 是取消罚金，
--   两者会在同一行同时存在（先发单计配送费，后取消计罚金），合并即永久丢失成本构成。
--
-- 为什么 cancel_reason 存 key 而不是快递100 的数字码
-- ------------------------------------------------
--   边缘函数把客户端传的 reason 字符串映射成对方要求的整数码（CANCEL_REASON_MAP）。
--   库里存映射前的 key：码表是快递100 的私有枚举，换服务商即作废，
--   存 key 则这列在换家后仍可读（与 provider_status 存原值形成对照，
--   后者换家后必须按 provider 分支解释，前者不必）。
--   取值范围见函数里的 CANCEL_REASON_MAP，未传时落 'other'。
--
-- 其他
-- ----
--   * 两列均可空，历史数据不受影响。
--   * delivered_at 已在原表中，无需新增；取消不写它。
--   * Dart 模型 lib/common/models/meal_delivery_order.dart 目前未映射本列
--     （客户端走 select() 全字段 + 忽略未知字段，新增列不会破坏解析）。

alter table public.meal_delivery_order
  add column if not exists cancel_fee    numeric(10,2),
  add column if not exists cancel_reason text;

comment on column public.meal_delivery_order.cancel_fee is
  '[通用] 第三方返回的取消费用，即我方为取消实际支付的罚金，单位元。与 provider_fee 并存，不可互相覆盖。';
comment on column public.meal_delivery_order.cancel_reason is
  '[通用] 取消原因 key（如 other / user_cancelled），由取消函数写入。存映射前的 key，不存快递100 的数字码，换服务商后仍可读。';