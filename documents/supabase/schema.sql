-- 备餐提醒：数据层改动
--
-- 执行环境：Supabase SQL Editor（线上）
-- 执行顺序：本文件所有语句都在同一个事务外按序执行；
--          先建列/表/索引，再建 RLS 和 PG 函数
--
-- 可重复执行：所有 create / alter 都带 if not exists。
-- 但 policy 和 function 不支持 if not exists，重复执行会报错——
-- 若需重新部署，先手动 drop policy / drop function 再跑。

-- ============================================================
-- 1) 幂等标记列
-- 为什么不用独立的提醒任务表：MVP 阶段只需要一个「提醒过没有」的标记，
-- 独立任务表要额外维护「订单取消/改期/状态变化时同步任务」，
-- 扫描式只需要一个标记列。将来要做「商家可配置提前量」「多次提醒」
-- 「静默时段」，再演进成任务表。
-- ============================================================
alter table public.meal_delivery_order
  add column if not exists preparation_reminded_at timestamptz;

-- 只给「该提醒还没提醒」的行建索引，避免全表扫。
-- 扫描 SQL 的 where 条件是 status='awaiting_preparation' + preparation_reminded_at is null，
-- 索引完全覆盖这两个条件，几千行的表也能毫秒级命中。
create index if not exists idx_mdo_prep_remind
  on public.meal_delivery_order (delivery_time)
  where status = 'awaiting_preparation'
    and preparation_reminded_at is null;

-- ============================================================
-- 2) 商家设备表
-- merchant_id 类型必须和 meal_delivery_order.merchant_id 一致（都是 uuid）。
-- unique 放在 tpns_token 上（不是 (merchant_id, tpns_token)）：
-- 卸载重装会换 token，旧 token 就废了；一个 token 只属于一台设备。
-- ============================================================
create table if not exists public.merchant_device (
  id             uuid primary key default gen_random_uuid(),
  merchant_id    uuid not null,
  tpns_token     text not null,
  platform       text not null default 'android',
  app_version    text,
  last_active_at timestamptz not null default now(),
  created_at     timestamptz not null default now(),
  unique (tpns_token)
);

alter table public.merchant_device enable row level security;

-- 归属判断写法照抄 meal_delivery_order 的 SELECT 策略：
-- merchant_id 不是 auth.uid()，而是通过 merchant 表间接关联。
-- 注意：策略里不要带 last_active_at / app_version 这种会随更新变化的列，
-- 将来若要给这张表开 Realtime，UPDATE 事件要求新旧两行都过策略，
-- 带易变列会导致「一改就收不到」。当前这张表不订阅 Realtime，但保持一致的写法。
create policy "商家读取自己店的设备"
  on public.merchant_device
  for select
  using (
    merchant_id in (
      select m.id from public.merchant m where m.user_id = auth.uid()
    )
  );

create policy "商家插入自己店的设备"
  on public.merchant_device
  for insert
  with check (
    merchant_id in (
      select m.id from public.merchant m where m.user_id = auth.uid()
    )
  );

create policy "商家更新自己店的设备"
  on public.merchant_device
  for update
  using (
    merchant_id in (
      select m.id from public.merchant m where m.user_id = auth.uid()
    )
  )
  with check (
    merchant_id in (
      select m.id from public.merchant m where m.user_id = auth.uid()
    )
  );

-- ============================================================
-- 3) PG 函数：认领 + 回滚
-- 为什么需要：Edge Function 里无法直接跑 SQL 事务，
-- 「查 + 更新」必须原子。用 UPDATE ... RETURNING 一步完成，
-- 谁拿到行谁负责推，多实例/重入不会重复。
-- ============================================================

create or replace function public.claim_due_meal_reminders(
  p_limit int default 100
)
returns table (
  id uuid,
  merchant_id uuid,
  delivery_time timestamptz
)
language sql
security definer
set search_path = public
as $$
  with due as (
    select m.id
    from public.meal_delivery_order m
    where m.status = 'awaiting_preparation'
      and m.preparation_reminded_at is null
      -- 触发点到了：送达前 45 分钟
      and m.delivery_time - interval '45 minutes' <= now()
      -- 僵尸单下界：两小时前的单不再提醒（否则历史遗留单会一次性糊脸）
      and m.delivery_time >= now() - interval '2 hours'
    order by m.delivery_time
    limit p_limit
    for update skip locked
  )
  update public.meal_delivery_order m
  set preparation_reminded_at = now()
  from due
  where m.id = due.id
  returning m.id, m.merchant_id, m.delivery_time;
$$;

-- 推送失败时回滚标记。
-- 决策：回滚而不是「标记了但没推」——
-- 回滚的代价是下一轮 cron 会再次认领并重试；不回滚的代价是这一单永远不再提醒。
-- 本项目只提醒一次，重试比漏推安全。
create or replace function public.rollback_meal_reminder(
  p_order_id uuid
)
returns void
language sql
security definer
set search_path = public
as $$
  update public.meal_delivery_order
  set preparation_reminded_at = null
  where id = p_order_id;
$$;

-- 只允许 service_role 调用（Edge Function 用的），anon / authenticated 一律禁止，
-- 防止客户端绕过服务端直接改提醒标记。
revoke all on function public.claim_due_meal_reminders(int) from public, anon, authenticated;
revoke all on function public.rollback_meal_reminder(uuid) from public, anon, authenticated;