// 快递100 同城急送「订单状态回调」接收端。
//
// 为什么 verify_jwt = false（见 supabase/config.toml）：
//   快递100 的服务器不带 Supabase JWT，若开启 JWT 校验，请求会在函数入口被直接
//   拒绝，回调永远进不来。因此鉴权改用快递100 自己的签名：sign = MD5(param + salt)，
//   salt 是下单时随 param 一起发出去的 DELIVERY_CALLBACK_SALT。
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

Deno.serve(async (req) => {
  try {
    // 快递100 按 form 表单 POST 提交，这里同时兼容 JSON body，便于本地联调。
    let taskId = '';
    let paramRaw = '';
    let sign = '';
    const contentType = req.headers.get('content-type') ?? '';
    if (contentType.includes('application/json')) {
      const body = await req.json();
      taskId = body.taskId ?? '';
      sign = body.sign ?? '';
      paramRaw = typeof body.param === 'string' ? body.param : JSON.stringify(body.param ?? {});
    } else {
      const form = await req.formData();
      taskId = String(form.get('taskId') ?? '');
      paramRaw = String(form.get('param') ?? '');
      sign = String(form.get('sign') ?? '');
    }
    console.log(`callback taskId: ${taskId}, param: ${paramRaw}, sign: ${sign}`);

    // 验签：sign = MD5(param + salt)。
    // param 必须用**原始字符串**参与计算 —— JSON.parse 再 JSON.stringify 会因键序、
    // 空格、数字格式的差异算出不同结果，导致合法回调被判成验签失败。
    const salt = Deno.env.get('DELIVERY_CALLBACK_SALT');
    if (!salt) {
      throw new Error('缺少 DELIVERY_CALLBACK_SALT');
    }
    const expected = md5(paramRaw + salt);
    if (!sign || sign.toLowerCase() !== expected.toLowerCase()) {
      console.error(`验签失败, expected: ${expected}, got: ${sign}`);
      return json({ result: false, returnCode: '500', message: '验签失败' }, 401);
    }

    const param = JSON.parse(paramRaw) as Record<string, unknown>;
    const orderId = String(param.orderId ?? '');
    const status = Number(param.status);
    if (!orderId || !Number.isFinite(status)) {
      return json({ result: false, returnCode: '500', message: '缺少 orderId 或 status' }, 400);
    }

    // 用 service_role 写库：回调没有用户身份，走不了 RLS。
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const update: Record<string, unknown> = {
      provider_status: status,
      provider_status_desc: param.statusDesc ?? null,
      courier_name: param.courierName ?? null,
      courier_mobile: param.courierMobile ?? null,
      last_callback_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    };
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

    // 按快递100 订单号定位配送单。provider_order_id 是下单成功时落库的。
    const { data, error } = await supabase
      .from('meal_delivery_order')
      .update(update)
      .eq('provider_order_id', orderId)
      .select('id');
    console.log(`updated: ${JSON.stringify(data)}, error: ${JSON.stringify(error)}`);
    if (error) {
      return json({ result: false, returnCode: '500', message: error.message }, 500);
    }
    if (!data?.length) {
      // 找不到单也返回成功，否则快递100 会重复回调 3 次；留日志人工排查即可。
      console.error(`未找到 provider_order_id=${orderId} 的配送单`);
      return json({ result: true, returnCode: '200', message: '订单不存在，已忽略' });
    }

    return json({ result: true, returnCode: '200', message: '提交成功' });
  } catch (err) {
    console.error(err);
    return json({ result: false, returnCode: '500', message: '服务器内部错误' }, 500);
  }
});