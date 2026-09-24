-- 20260922170000_add_delivery_provider_fields
--
-- 为「接入第三方同城配送（快递100 同城急送）」补齐落库字段。
--
-- 前置条件（顺序不能反）
-- --------------------
--   必须先执行 20260922163200_restrict_meal_delivery_order_read.sql。
--   原因：meal_delivery_order 原 SELECT 策略是 USING (true)（对 public 全开），
--   任何字段放进这张表都等同公开。本次新增的 courier_mobile 是骑手手机号，
--   属于 PII，必须先收敛读取范围再上本迁移。
--
-- 为什么不拆独立表
-- ----------------
--   曾考虑把第三方字段迁到 meal_delivery_provider_ref 之类的独立表，以便
--   「后续更换服务商」。结论是不拆，理由：
--
--     1. 换服务商要改的是边缘函数，不是表。与快递100 耦合的东西全部在
--        supabase/functions/dispatch-delivery-order 与 delivery-order-callback 里：
--        接口地址、method 取值、sign 算法、param 字段名、状态码枚举——无一在库中。
--        换家时表最多改几个列名。
--     2. 拆表解决不了换家时的真问题。在途单仍须用旧家的 orderId 才能取消/查询，
--        因此 provider_order_id 不能被新家的号覆盖。这个约束在同表多列与独立表
--        中完全一样，拆表并不使在途单更好处理。
--     3. 拆表有真实成本。客户端现为单表 select()，Dart 模型 MealDeliveryOrder
--        直接映射本表；拆表后每次读取都要 join，模型也要跟着拆。
--     4. 若将来真出现第二家，届时再迁移成本很低（一次 add column，或一次建表 +
--        insert ... select），而且那时才知道第二家的数据长什么样；现在设计等于盲猜。
--
--   预留的门是 delivery_provider 列本身。
--
-- 列的分组（换服务商时的处置方式）
-- ------------------------------
--   A. 服务商凭证列——与具体服务商强绑定：
--        provider_task_id / provider_order_id / provider_status / provider_status_desc
--      其中 provider_status 存的是对方枚举原值（0/100/210/230/310/515/510/520/720），
--      换家后语义对不上，需要新增列或按 provider 分支解释。
--   B. 通用配送能力列——任何一家同城配送都需要，与快递100 无关：
--        delivery_provider / courier_name / courier_mobile /
--        dispatched_at / dispatch_failed_reason / last_callback_at
--
-- 不存 provider_salt
-- -----------------
--   回调签名 MD5(param + salt) 里的 salt 是「我们自己传给快递100 的共享密钥」，
--   放在 Edge Function Secrets（DELIVERY_CALLBACK_SALT）即可。数据库里没有需要
--   保护的密钥，也就不需要额外的密钥表。
--
-- 其他
-- ----
--   * 全部新列可空，3126 行历史数据不受影响。
--   * 未加 cancel_fee：取消流程尚未实现，无任何代码写入该列，等做取消时再加。
--   * Dart 模型 lib/models/meal_delivery_order.dart 目前未映射这些列。
--     客户端查询走 select()（全字段）+ 忽略未知字段，故新增列不会破坏现有解析；
--     待商家端/用户端需要展示骑手信息时，再在模型中补 courier_name / courier_mobile。

-- 1) 配送单补充第三方配送字段
alter table public.meal_delivery_order
  add column if not exists delivery_provider      text,
  add column if not exists provider_task_id       text,
  add column if not exists provider_order_id      text,
  add column if not exists provider_status        integer,
  add column if not exists provider_status_desc   text,
  add column if not exists provider_fee           numeric(10,2),
  add column if not exists courier_name           text,
  add column if not exists courier_mobile         text,
  add column if not exists dispatched_at          timestamptz,
  add column if not exists dispatch_failed_reason text,
  add column if not exists last_callback_at       timestamptz;

-- 2) 列注释：写清分组与口径，避免下次再逐列追问
comment on column public.meal_delivery_order.delivery_provider is
  '[通用] 第三方配送服务商标识，由发单函数写入，如 kuaidi100。为将来换服务商预留的判别字段。';
comment on column public.meal_delivery_order.provider_task_id is
  '[服务商凭证] 快递100 的 taskId，取消订单、加小费时必填。';
comment on column public.meal_delivery_order.provider_order_id is
  '[服务商凭证] 快递100 的 orderId，状态回调的唯一对账主键。有唯一索引，不可被其他服务商覆盖。';
comment on column public.meal_delivery_order.provider_status is
  '[服务商凭证] 快递100 原始状态码，取值 0/100/210/230/310/515/510/520/720。存对方枚举原值，换服务商后语义不通用。';
comment on column public.meal_delivery_order.provider_status_desc is
  '[服务商凭证] 上述原始状态码对应的中文描述，便于客服直接阅读。';
comment on column public.meal_delivery_order.provider_fee is
  '[通用] 第三方返回的折扣配送费，即我方实际支付的成本，单位元。注意与 delivery_fee 区分：delivery_fee 是向用户收取的配送费。';
comment on column public.meal_delivery_order.courier_name is
  '[通用] 第三方骑手姓名，由状态回调写入，用于替代原占位骑手。';
comment on column public.meal_delivery_order.courier_mobile is
  '[通用] 第三方骑手手机号，由状态回调写入。属于 PII，依赖 20260922163200 的读取策略收敛。';
comment on column public.meal_delivery_order.dispatched_at is
  '[通用] 发单成功（拿到第三方单号）的时间。';
comment on column public.meal_delivery_order.dispatch_failed_reason is
  '[通用] 最近一次发单失败的原因，供商家端排障；发单成功后清空。';
comment on column public.meal_delivery_order.last_callback_at is
  '[通用] 最后一次收到第三方状态回调的时间，用于判断回调通道是否仍然正常。';

-- 3) 回调查找 + 幂等兜底：一个第三方订单号只能对应一张配送单。
--    部分索引（where provider_order_id is not null）避免历史空值互相冲突。
create unique index if not exists uniq_meal_delivery_provider_order
  on public.meal_delivery_order (delivery_provider, provider_order_id)
  where provider_order_id is not null;

-- 4) 回调原文审计表：用于对账、排障与重放分析
create table if not exists public.delivery_callback_event (
  id                uuid primary key default uuid_generate_v4(),
  provider          text        not null default 'kuaidi100',
  provider_order_id text,
  provider_task_id  text,
  status            integer,
  status_desc       text,
  courier_name      text,
  courier_mobile    text,
  sign_verified     boolean     not null default false,
  applied           boolean     not null default false,
  note              text,
  raw_param         text,
  received_at       timestamptz not null default now()
);

comment on table public.delivery_callback_event is
  '第三方配送状态回调原文审计。无论验签成功与否都落一行；仅 service_role 可访问。';
comment on column public.delivery_callback_event.sign_verified is
  '回调签名是否校验通过。为 false 时不得用于更新配送单，仅留档。';
comment on column public.delivery_callback_event.applied is
  '本次回调是否已成功应用到 meal_delivery_order。为 false 时可用于重放。';
comment on column public.delivery_callback_event.raw_param is
  '回调原始 param 报文，保留原文以便事后重算签名、排查解析问题。';

create index if not exists idx_delivery_callback_event_order
  on public.delivery_callback_event (provider, provider_order_id);
create index if not exists idx_delivery_callback_event_received
  on public.delivery_callback_event (received_at desc);

-- 5) 锁死访问：RLS 开启且不建任何 policy = anon/authenticated 一律拒绝；
--    service_role 绕过 RLS，回调函数照常写入。
--    Supabase 对新表默认会给 anon/authenticated 授权，这里显式收回做双保险。
alter table public.delivery_callback_event enable row level security;
revoke all on public.delivery_callback_event from anon, authenticated;