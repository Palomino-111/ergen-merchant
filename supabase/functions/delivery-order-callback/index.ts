// 快递100 同城急送「订单状态回调」接收端。
//
// 为什么 verify_jwt = false（见 supabase/config.toml）：
//   快递100 的服务器不带 Supabase JWT，若开启 JWT 校验，请求会在函数入口被直接
//   拒绝，回调永远进不来。因此鉴权改用快递100 自己的签名：sign = MD5(param + salt)，
//   salt 是下单时随 param 一起发出去的 DELIVERY_CALLBACK_SALT。
//
// 两件事，职责分开：
//   1. 应用状态：验签通过 → 更新 meal_delivery_order（只在通过时做）
//   2. 审计留档：**无论验签是否通过**都往 delivery_callback_event 落一行
//      （约定见迁移 20260922170000 第 4 节：sign_verified 为 false 时不得用于
//       更新配送单，仅留档；applied 为 false 时可用于重放）
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'npm:@supabase/supabase-js@2';
import md5 from 'npm:blueimp-md5@2.19.0';
console.info('server started');

// 快递100 回调状态码 → 我方 delivery_status。
// 未列出的状态（如 510 订单状态异常、515 转单改派中）是非终态：
// 只更新 provider_status 等展示字段，不动主状态，避免把异常单误标成配送中。
const STATUS_MAP: Record<number, string> = {
  0: 'awaiting_delivery', // 下单成功
  100: 'awaiting_delivery', // 已接单
  210: 'awaiting_delivery', // 待取件
  230: 'awaiting_delivery', // 已到店
  310: 'delivering', // 配送中
  520: 'delivered', // 已完成
  720: 'cancelled' // 订单取消
};

// 统一响应包装。快递100 只认 result / returnCode / message 三个字段，其余忽略。
function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' }
  });
}

// 审计行。字段与 delivery_callback_event 一一对应。
type AuditRow = {
  provider: string;
  provider_order_id: string | null;
  provider_task_id: string | null;
  status: number | null;
  status_desc: string | null;
  courier_name: string | null;
  courier_mobile: string | null;
  sign_verified: boolean;
  applied: boolean;
  note: string | null;
  raw_param: string | null;
};

Deno.serve(async (req) => {
  // service_role：回调没有用户身份，走不了 RLS；审计表也只对 service_role 开放。
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  );

  // 审计行先建空壳，各出口只改它，最后由 finally 统一落库。
  // 这样出口不必各自 await audit：少 6 处重复调用，note 成为唯一的失败说明，
  // 且 catch 分支也能留痕（此前未捕获异常在审计表里是完全不存在的）。
  const row: AuditRow = {
    provider: 'kuaidi100',
    provider_order_id: null,
    provider_task_id: null,
    status: null,
    status_desc: null,
    courier_name: null,
    courier_mobile: null,
    sign_verified: false,
    applied: false,
    note: null,
    raw_param: null
  };

  try {
    // 快递100 按文档发 form 表单（x-www-form-urlencoded）。
    // 不兼容 JSON body：那需要把 param 重新 JSON.stringify 才能参与验签，
    // 而键序/空格一变签名必然对不上，等于给自己埋一个"必然验签失败"的分支。
    const form = await req.formData();
    const taskId = String(form.get('taskId') ?? '');
    const paramRaw = String(form.get('param') ?? '');
    const sign = String(form.get('sign') ?? '');
    console.log(`callback taskId: ${taskId}, param: ${paramRaw}, sign: ${sign}`);

    row.provider_task_id = taskId || null;
    // raw_param 存**原始字符串**，不做 parse 后再序列化 —— 那会因键序、空格、数字
    // 格式的差异失真，而这张表的用途正是「事后重算签名」（与验签同一个坑）。
    row.raw_param = paramRaw || null;

    // ---- 1) 验签：sign = MD5(param + salt) ----
    const salt = Deno.env.get('DELIVERY_CALLBACK_SALT');
    if (!salt) {
      // 部署失误，不是回调的问题。仍落一行审计，否则这次投递会彻底消失。
      row.note = '服务端未配置 DELIVERY_CALLBACK_SALT';
      return json({ result: false, returnCode: '500', message: '服务端未配置回调密钥' }, 500);
    }
    const expected = md5(paramRaw + salt);
    if (!sign || sign.toLowerCase() !== expected.toLowerCase()) {
      // 伪造或串号的回调：不更新任何配送单，但必须留档。
      // 关掉 verify_jwt 之后这是唯一的防线，没有这条记录就等于无痕。
      row.note = '验签失败，未应用';
      console.error(`验签失败, expected: ${expected}, got: ${sign}`);
      return json({ result: false, returnCode: '500', message: '验签失败' }, 401);
    }
    row.sign_verified = true;

    // ---- 2) 解析 param ----
    let param: Record<string, unknown>;
    try {
      param = JSON.parse(paramRaw) as Record<string, unknown>;
    } catch (e) {
      // 验签都过了却解析不了：说明我方与对方的序列化约定出了问题，值得留档排查。
      row.note = `param 不是合法 JSON: ${e instanceof Error ? e.message : String(e)}`;
      return json({ result: false, returnCode: '500', message: 'param 解析失败' }, 400);
    }

    const orderId = String(param.orderId ?? '');
    const status = Number(param.status);
    const statusOk = Number.isFinite(status);
    row.provider_order_id = orderId || null;
    row.status = statusOk ? status : null;
    row.status_desc = param.statusDesc ? String(param.statusDesc) : null;
    row.courier_name = param.courierName ? String(param.courierName) : null;
    row.courier_mobile = param.courierMobile ? String(param.courierMobile) : null;

    if (!orderId || !statusOk) {
      row.note = '缺少 orderId 或 status';
      return json({ result: false, returnCode: '500', message: '缺少 orderId 或 status' }, 400);
    }

    // ---- 3) 应用到配送单 ----
    const update: Record<string, unknown> = {
      provider_status: status,
      provider_status_desc: row.status_desc,
      last_callback_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    };
    if (row.courier_name) {
      update.courier_name = row.courier_name;
    }
    if (row.courier_mobile) {
      update.courier_mobile = row.courier_mobile;
    }
    const mapped = STATUS_MAP[status];
    if (mapped) {
      update.status = mapped;
    }
    if (status === 520) {
      update.delivered_at = new Date().toISOString();
    }
    // cancelReason 仅当状态为 720 且下游返回时才存在。
    if (status === 720 && param.cancelReason) {
      update.dispatch_failed_reason = String(param.cancelReason);
    }

    // 按快递100 订单号定位配送单。
    // 必须同时过滤 delivery_provider：库里的唯一索引是 (delivery_provider,
    // provider_order_id) 复合索引，provider_order_id **单列并不唯一**。
    // 只按订单号更新，将来接入第二家运力且撞号时会同时命中两行，静默改错单。
    const { data, error } = await supabase
      .from('meal_delivery_order')
      .update(update)
      .eq('delivery_provider', 'kuaidi100')
      .eq('provider_order_id', orderId)
      .select('id');

    if (error) {
      row.note = `落库失败: ${error.message}`;
      return json({ result: false, returnCode: '500', message: error.message }, 500);
    }
    if (!data?.length) {
      // 找不到单也返回成功，否则快递100 会重复回调 3 次。
      // applied 保持 false，这张审计行就是事后排查/重放的依据（note 已持久化，不再打日志）。
      row.note = '未找到匹配的配送单，未应用';
      return json({ result: true, returnCode: '200', message: '订单不存在，已忽略' });
    }

    // ponytail: 不做乱序保护 —— 若先收 520 再收重试的 310，订单会被改回配送中。
    // 依赖快递100 按序推送；真出现回退再加跨状态偏序校验（720 是任意态可达的终态，
    // 偏序不是一行能定义的，现在写等于盲猜）。
    row.applied = true;
    return json({ result: true, returnCode: '200', message: '提交成功' });
  } catch (err) {
    // 未捕获异常也必须留痕，否则这次投递在审计表里不存在。
    row.note = `未捕获异常: ${err instanceof Error ? err.message : String(err)}`;
    console.error(err);
    return json({ result: false, returnCode: '500', message: '服务器内部错误' }, 500);
  } finally {
    // 唯一的审计落库点，覆盖上面所有 return 与 catch 分支。
    // 写入失败不改变响应，只记 error 日志：否则会把审计故障放大成
    // 快递100 的 3 次重试投递。
    const { error } = await supabase.from('delivery_callback_event').insert(row);
    if (error) {
      console.error(`审计写入失败（${row.note ?? '已应用'}）: ${JSON.stringify(error)}`);
    } else {
      console.log(`审计已记录: orderId=${row.provider_order_id} status=${row.status} applied=${row.applied}`);
    }
  }
});
