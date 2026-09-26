// 快递100 同城急送「获取骑手位置」入口。
//
// 职责边界：只做查询。位置在快递100 侧**计费**，所以没做成客户端可直连的读接口，
// 一次请求只打一次快递100，不做轮询/重试。
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'npm:@supabase/supabase-js@2';
import md5 from 'npm:blueimp-md5@2.19.0';
console.info('server started');

// 测试环境地址。快递100 同城急送的测试环境 = 把正式地址换成下面这个。
// ⚠️ 正式环境是 https://api.kuaidi100.com/bsamecity/order。
//    部署前务必确认打到哪个环境 —— 误打到正式会真实扣费。
const KUAIDI100_URL = 'http://e-test.kuaidilab.com/api/bsamecity/order';

// 可查询的本地状态。骑手接单后才有位置，所以只放行在途状态。
// 不含 delivered / received：行程已结束，白花一次计费调用。
// 不含 awaiting_preparation / preparing：还没发单，连 provider_order_id 都没有。
const POSITION_QUERYABLE_STATUSES = ['awaiting_delivery', 'delivering'];

// 统一响应包装：JSON body + Content-Type，避免每处 return 重复三行 headers。
function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' }
  });
}

/**
 * 调用快递100 同城急送**骑手位置**接口。
 *
 * 签名规则：sign = MD5(param + t + key + secret)，32 位大写。
 * param 必须与签名使用同一份序列化结果，否则会 30002 验证签名失败。
 */
async function callKuaidi100(method: string, param: Record<string, unknown>) {
  const key = Deno.env.get('KUAIDI100_KEY');
  const secret = Deno.env.get('KUAIDI100_SECRET');
  if (!key || !secret) {
    throw new Error('缺少 KUAIDI100_KEY / KUAIDI100_SECRET');
  }
  const t = Date.now().toString();
  const paramJson = JSON.stringify(param);
  const sign = md5(paramJson + t + key + secret).toUpperCase();
  console.log(`kuaidi100 request, method: ${method}, t: ${t}, param: ${paramJson}`);
  const res = await fetch(KUAIDI100_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ method, key, t, sign, param: paramJson })
  });
  const text = await res.text();
  console.log(`kuaidi100 response: ${text}`);
  if (!res.ok) {
    throw new Error(`快递100 HTTP ${res.status}: ${text}`);
  }
  return JSON.parse(text);
}

Deno.serve(async (req) => {
  try {
    // 1. 建 supabase 客户端
    // 必须把用户 JWT 显式转发给 PostgREST，auth.uid() 才等于该用户，RLS 才有身份。
    // 不能用 headers: req.headers —— req.headers 是 Headers 实例，supabase-js 用对象
    // 展开合并（{...headers}），而展开 Headers 得到 {}，Authorization 会被静默丢掉。
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return json({ error: '缺少 Authorization' }, 401);
    }
    const supabase = createClient(Deno.env.get('SUPABASE_URL') ?? '', JSON.parse(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS')!)['default'], {
      global: {
        headers: { Authorization: authHeader }
      }
    });
    // 2. 获取请求数据。只收配送单 id，orderId 查库补齐 —— 收客户端传的等于允许任何人查别人的骑手位置。
    const { meal_delivery_order_id: deliveryOrderId } = await req.json();
    console.log(`meal_delivery_order_id: ${deliveryOrderId}`);
    if (!deliveryOrderId) {
      return json({ error: '缺少 meal_delivery_order_id' }, 400);
    }
    // 3. 通过 auth 获取 user，确认 token 有效
    const token = authHeader.replace('Bearer ', '');
    const { data: user } = await supabase.auth.getUser(token);
    if (!user?.user) {
      return json({ error: 'token 无效或已过期' }, 401);
    }
    // 4. 读配送单
    const { data: deliveryOrder, error: deliveryOrderError } = await supabase
      .from('meal_delivery_order')
      .select('id, merchant_id, status, delivery_provider, provider_order_id')
      .eq('id', deliveryOrderId)
      .maybeSingle();
    console.log(`deliveryOrder: ${JSON.stringify(deliveryOrder)}, deliveryOrderError: ${JSON.stringify(deliveryOrderError)}`);
    if (deliveryOrderError) {
      return json({ error: '读取配送单失败', detail: deliveryOrderError.message }, 500);
    }
    if (!deliveryOrder) {
      return json({ error: '配送单不存在或无权访问' }, 404);
    }
    // 5. 校验归属。merchant 的 SELECT 策略是公开可读（USING true），RLS 不构成归属校验，
    // 必须显式比对 user_id。先归属后状态，否则会泄露「这单存不存在」。
    const { data: merchant, error: merchantError } = await supabase
      .from('merchant')
      .select('id, user_id')
      .eq('id', deliveryOrder.merchant_id)
      .maybeSingle();
    console.log(`merchant: ${JSON.stringify(merchant)}, merchantError: ${JSON.stringify(merchantError)}`);
    if (merchantError) {
      return json({ error: '读取商家失败', detail: merchantError.message }, 500);
    }
    if (!merchant) {
      return json({ error: '商家不存在' }, 404);
    }
    if (merchant.user_id !== user.user.id) {
      return json({ error: '无权查询该配送单' }, 403);
    }
    // 6. 状态校验
    if (!POSITION_QUERYABLE_STATUSES.includes(deliveryOrder.status)) {
      return json({ error: `当前状态 ${deliveryOrder.status} 无法查询骑手位置` }, 409);
    }
    // 7. 服务商校验：只有快递100 发的单才有 orderId 可查。
    if (deliveryOrder.delivery_provider !== 'kuaidi100') {
      return json({ error: '该配送单非快递100 运力，无法查询骑手位置' }, 409);
    }
    if (!deliveryOrder.provider_order_id) {
      return json({ error: '该配送单缺少第三方单号，无法查询骑手位置' }, 409);
    }
    // 8. 查询骑手位置
    const resp = await callKuaidi100('queryCourier', { orderId: deliveryOrder.provider_order_id });
    // code 用 Number() 比较：该网关会输出字符串化数字字段（文档把 lbsType 标成 String），
    // 严格 !== 200 会把一次成功判成失败。
    if (!resp.success || Number(resp.code) !== 200) {
      return json({ error: '查询骑手位置失败', code: resp.code, detail: resp.message }, 502);
    }
    // 9. 坐标校验。实测（2026-09-26）：骑手未上报定位时上游回的是 `code=30005
    //    无法查询配送员位置!`，在上一行就被拦成 502，走不到这里 —— 四种状态
    //    （0 下单成功 / 100 已接单 / 230 已到店 / 310 配送中）全是这个结果。
    //    这道校验只防「上游回 200 但坐标缺失」，按数值判空是因为客户端要直接
    //    double.parse：只判空串的话 '  ' / 'NaN' 会漏过去抛错。
    const data = resp.data ?? {};
    const validCoord = (v: unknown): boolean =>
      v !== undefined && v !== null && String(v).trim() !== '' && Number.isFinite(Number(v));
    const lat = data.courierLat;
    const lng = data.courierLng;
    if (!validCoord(lat) || !validCoord(lng)) {
      return json({
        has_position: false,
        message: '骑手尚未上报位置'
      });
    }
    return json({
      has_position: true,
      // 统一成 string 返回：客户端不必纠结数字/字符串两种形态。
      courier_lat: String(lat),
      courier_lng: String(lng),
      // 文档 6.3：lbsType 恒为 2（高德坐标），缺失时按 2 兜底。
      lbs_type: Number(data.lbsType ?? 2),
      provider_order_id: deliveryOrder.provider_order_id
    });
  } catch (err) {
    // 兜住意外异常（body 非 JSON、header 缺失、字段访问越界、fetch 抛错等），
    // 保证前端永远拿到统一的 JSON，而不是 runtime 的裸 500。
    console.error(err);
    return json({ error: '服务器内部错误' }, 500);
  }
});
