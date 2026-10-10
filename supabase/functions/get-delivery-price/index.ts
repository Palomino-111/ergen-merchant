// 快递100 同城急送「价格查询」入口（method=price）。
//
// 职责边界：只询价。不发单、不落库、不写任何列。
// 发单在 dispatch-delivery-order，取消在 cancel-delivery-order，骑手位置在 get-courier-position。
//
// 文档「一、同城急送价格查询接口」原文：该接口并非真正发单，是用来验证是否可以发单并
// 在成功时返回时效、计价等信息，也可用来验证地址以及时间是否在快递公司的配送范围内。
// 按文档不产生实际费用，但它仍是一次真实上游调用，且结果只代表「此刻」的报价。
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'npm:@supabase/supabase-js@2';
import md5 from 'npm:blueimp-md5@2.19.0';
console.info('server started');

// 测试环境地址。快递100 同城急送的测试环境 = 把正式地址换成下面这个。
// ⚠️ 正式环境是 https://api.kuaidi100.com/bsamecity/order。
//    部署前务必确认打到哪个环境 —— 误打到正式会真实扣费。
const KUAIDI100_URL = 'http://e-test.kuaidilab.com/api/bsamecity/order';

// ⚠️ 询价参数必须与 dispatch-delivery-order **逐字一致**，否则报出来的价与真实扣费对不上。
//    这两个常量与发单函数里的同名常量是同一份口径，改一处必须同步另一处。
//    运力：达达。快递100 侧称「快递公司编码」，命名规律为「品牌 + tongcheng」。
//    实测（2026-09-23）：测试环境下只有 dadatongcheng 能发单成功。
const KUAIDICOM = 'dadatongcheng';

// 默认重量（kg）。餐品实际重量未采集，与发单用同一个估算值 ——
// 询价一旦改用「更真实」的重量，报出的价就不再是发单将要扣的那笔钱。
const DEFAULT_WEIGHT_KG = '1';

// 可询价状态 = 可发单状态。报价是给「要不要叫骑手」做决策用的；
// 发单之后成本已成事实（provider_fee 落库），再询价只会让两个数字互相打架。
// 不含 cancelled：该单不可能再发单（发单白名单不收 cancelled），报价没有出口。
const QUOTABLE_STATUSES = ['awaiting_preparation', 'preparing'];

// 统一响应包装：JSON body + Content-Type，避免每处 return 重复三行 headers。
function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' }
  });
}

/**
 * 调用快递100 同城急送**价格查询**接口。
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
  // 网关可能在 HTTP 200 下回 HTML；显式抛错，别伪装成我方的「服务器内部错误」。
  try {
    return JSON.parse(text);
  } catch {
    throw new Error(`快递100 返回非 JSON（HTTP ${res.status}）: ${text.slice(0, 200)}`);
  }
}

/**
 * 数值归一：该网关的数字字段可能回字符串（文档把 cancelFee / lbsType 都标成 String）。
 * 只有「非空且能转成有限数」才认，其余一律 null —— 空串走 Number('') === 0 会变成假数据。
 */
const num = (v: unknown): number | null =>
  v !== undefined && v !== null && String(v).trim() !== '' && Number.isFinite(Number(v)) ? Number(v) : null;

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
    // 2. 取请求数据。只收配送单 id，地址、金额一律服务端查库，绝不信任客户端 ——
    //    否则任何人都能拿别人的地址来询价，等于开放一个免费的地理编码探针。
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
    // 4. 读配送单。显式列出用到的列，不用 select()：本函数不需要骑手手机号等 PII。
    const { data: deliveryOrder, error: deliveryOrderError } = await supabase
      .from('meal_delivery_order')
      .select('id, merchant_id, status, total_paid, recipient_name, phone, province, city, district, detailed_address, latitude, longitude, meal_snapshot')
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
    //    必须显式比对 user_id。先归属后状态：反过来会泄露「这单存不存在」。
    const { data: merchant, error: merchantError } = await supabase
      .from('merchant')
      .select('id, user_id, name, phone, province, city, district, detailed_address, latitude, longitude')
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
    if (!QUOTABLE_STATUSES.includes(deliveryOrder.status)) {
      return json({ error: `当前状态 ${deliveryOrder.status} 无法查询价格` }, 409);
    }
    // 7. 物品金额校验。快递100 要求 param.price > 0，否则先被 30005「物品总金额必须大于0」
    //    挡下（发单时实测踩过，见 supabase/config.toml 的 callbackUrl 备注）。
    //    这种单在发单时同样会被拒，与其白跑一次上游再报一个含糊的 30005，不如本地直接说清。
    //    不兜底成 0.01：price 是申报的物品价值，编造它会影响理赔口径。
    const declaredPrice = Number(deliveryOrder.total_paid);
    if (!Number.isFinite(declaredPrice) || declaredPrice <= 0) {
      return json({
        error: '配送单的物品金额（total_paid）缺失或不大于 0，无法询价',
        detail: '快递100 要求 param.price > 0，否则返回 30005「物品总金额必须大于0」'
      }, 409);
    }
    // 8. 组装 param。与 dispatch-delivery-order 同一份字段与口径：寄件人 = 商家取货地址，
    //    收件人 = 配送单收货地址，立即单（orderType=0）。
    //    不传 salt / callbackUrl：那两个只服务于真实发单后的状态回调，询价没有回调。
    //    坐标按库中原值透传，不做补零/截断：约定由写入方保证恰好 6 位小数（快递100 的要求），
    //    位数不对由上游回 30001 暴露，本函数不替它掩盖数据问题。
    const param: Record<string, unknown> = {
      kuaidicom: KUAIDICOM,
      sendManName: merchant.name,
      sendManMobile: merchant.phone,
      sendManProvince: merchant.province,
      sendManCity: merchant.city,
      sendManDistrict: merchant.district,
      sendManAddr: merchant.detailed_address,
      sendManLat: String(merchant.latitude),
      sendManLng: String(merchant.longitude),
      recManName: deliveryOrder.recipient_name,
      recManMobile: deliveryOrder.phone,
      recManProvince: deliveryOrder.province,
      recManCity: deliveryOrder.city,
      recManDistrict: deliveryOrder.district,
      recManAddr: deliveryOrder.detailed_address,
      recManLat: String(deliveryOrder.latitude),
      recManLng: String(deliveryOrder.longitude),
      weight: DEFAULT_WEIGHT_KG,
      // 与发单同样的字符串化写法，保证两次调用的 param 逐字一致（不同则报价不可比）。
      price: String(declaredPrice),
      goods: [{ type: '食品', count: 1, name: deliveryOrder.meal_snapshot?.name ?? '外卖' }],
      orderType: 0
    };
    // 9. 询价
    const resp = await callKuaidi100('price', param);
    // code 用 Number() 比较：该网关会输出字符串化数字字段（文档把 cancelFee / lbsType
    // 都标成 String），严格 !== 200 会把一次成功判成失败。
    if (!resp.success || Number(resp.code) !== 200) {
      // 刻意**不**写 dispatch_failed_reason：那一列的语义是「最近一次发单失败的原因」，
      // 询价失败不是发单失败，写进去会把商家端排障引到错误方向。
      return json({ error: '查询价格失败', code: resp.code, detail: resp.message }, 502);
    }
    // 10. data 缺失时不假装知道价格：discountFee 可能是 '' 或非数字，
    //     Number('') === 0 会报出一个假的「免费」。
    const data = resp.data ?? {};
    const fee = num(data.discountFee);
    const hasFee = fee !== null;
    const distance = num(data.deliveryDistance);
    if (!hasFee) {
      console.warn(`快递100 询价成功但未返回 discountFee，费用未知: ${JSON.stringify(resp)}`);
    }
    return json({
      // 字段名与发单接口保持一致，调用方可直接复用解析逻辑；但这里恒为**预估**，
      // 真实成本以发单返回的 provider_fee / 库里的 provider_fee 为准。
      provider_fee: fee,
      // data 缺失时费用未知，别让调用方把「不知道」读成「免费」。
      fee_known: hasFee,
      // 预估配送距离，单位：米。上游未返回或非数字时为 null。
      delivery_distance: distance,
      // 本次报价对应的运力。将来若支持多运力并呼，这里会决定用哪家。
      kuaidicom: KUAIDICOM
      // 刻意不回传上游的 taskId：它是询价流水号，与发单后的 provider_task_id 毫无关系，
      // 透出去迟早有人拿它去调取消接口。需要排障时按日志里的 param 查。
    });
  } catch (err) {
    // 兜住意外异常（body 非 JSON、header 缺失、字段访问越界、fetch 抛错等），
    // 保证前端永远拿到统一的 JSON，而不是 runtime 的裸 500。
    console.error(err);
    return json({ error: '服务器内部错误' }, 500);
  }
});
