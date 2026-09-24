// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'npm:@supabase/supabase-js@2';
import md5 from 'npm:blueimp-md5@2.19.0';
console.info('server started');

// 快递100 同城急送发单入口。取消、加小费是另外的 method，但都不在本函数职责内，
// 将来做取消时另建函数，不要往这里堆 method 分支。
// 测试环境地址。快递100 同城急送的测试环境 = 把正式地址换成下面这个。
// ⚠️ 正式环境是 https://api.kuaidi100.com/bsamecity/order。
//    部署前务必确认打到哪个环境 —— 误打到正式会真实扣费。
const KUAIDI100_URL = 'http://e-test.kuaidilab.com/api/bsamecity/order';

// 允许发单的起始状态。备餐完成前不该发单。
// 不含 awaiting_delivery：那是本函数成功后的目标状态，放行它等于允许对已发单的单重复发单。
const DISPATCHABLE_STATUSES = ['awaiting_preparation', 'preparing'];

// 运力：达达。快递100 侧称「快递公司编码」，命名规律为「品牌 + tongcheng」。
// 同级编码：shunfengtongcheng（顺丰同城）/ meituantongcheng（美团跑腿）/ fengniaotongcheng（蜂鸟）。
// ⚠️ 实测（2026-09-23）：测试环境下**只有 dadatongcheng 能发单成功**；
//    shunfengtongcheng 与 meituantongcheng 均返回 30005「该运力暂不支持该地址」。
const KUAIDICOM = 'dadatongcheng';

// 默认重量（kg）。餐品实际重量未采集，先用固定值估算：
// 一份餐（含打包）通常远低于 1kg，1 已足够覆盖且不会因低报被运力方判异常。
const DEFAULT_WEIGHT_KG = '1';

// 统一响应包装：JSON body + Content-Type，避免每处 return 重复三行 headers。
function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' }
  });
}

/**
 * 调用快递100 同城急送**发单**接口。
 *
 * 签名规则：sign = MD5(param + t + key + secret)，32 位大写。
 * param 必须与签名使用同一份序列化结果，否则会 30002 验证签名失败。
 */
async function callKuaidi100(param: Record<string, unknown>) {
  const key = Deno.env.get('KUAIDI100_KEY');
  const secret = Deno.env.get('KUAIDI100_SECRET');
  if (!key || !secret) {
    throw new Error('缺少 KUAIDI100_KEY / KUAIDI100_SECRET');
  }
  const t = Date.now().toString();
  const paramJson = JSON.stringify(param);
  const sign = md5(paramJson + t + key + secret).toUpperCase();
  console.log(`kuaidi100 request, t: ${t}, param: ${paramJson}`);
  const res = await fetch(KUAIDI100_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ method: 'order', key, t, sign, param: paramJson })
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
    // 1. 初始化数据库客户端
    // 注意：
    // 1. SUPABASE_ANON_KEY、SUPABASE_SERVICE_ROLE_KEY等key只能使用一个，只会有一个生效；
    // 2. 在边缘函数中一般直接使用SUPABASE_SERVICE_ROLE_KEY，默认对数据库有所有的操作权限，直接绕过RLS；
    //
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
    // 2. 获取请求数据。只收配送单 id，地址、金额一律服务端查库，绝不信任客户端。
    const { meal_delivery_order_id: deliveryOrderId } = await req.json();
    console.log(`meal_delivery_order_id: ${deliveryOrderId}`);
    if (!deliveryOrderId) {
      return json({ error: '缺少 meal_delivery_order_id' }, 400);
    }
    // 3. 通过auth获取user信息，然后就可以通过user获取id（user_id）了
    const token = authHeader.replace('Bearer ', '');
    const { data: user } = await supabase.auth.getUser(token);
    console.log(`user: ${JSON.stringify(user)}`);
    if (!user?.user) {
      return json({ error: 'token 无效或已过期' }, 401);
    }
    // 4. 读取配送单
    const { data: deliveryOrder, error: deliveryOrderError } = await supabase.from('meal_delivery_order').select().eq('id', deliveryOrderId).maybeSingle();
    console.log(`deliveryOrder: ${JSON.stringify(deliveryOrder)}, deliveryOrderError: ${JSON.stringify(deliveryOrderError)}`);
    if (deliveryOrderError) {
      return json({ error: '读取配送单失败', detail: deliveryOrderError.message }, 500);
    }
    if (!deliveryOrder) {
      return json({ error: '配送单不存在或无权访问' }, 404);
    }
    // 5. 幂等：已发过单且未取消就直接返回，避免重复产生真实运力订单（发单会真实扣费）
    if (deliveryOrder.provider_order_id && deliveryOrder.status !== 'cancelled') {
      return json({
        already_dispatched: true,
        provider_order_id: deliveryOrder.provider_order_id,
        provider_task_id: deliveryOrder.provider_task_id,
        status: deliveryOrder.status
      });
    }
    // 6. 状态校验
    if (!DISPATCHABLE_STATUSES.includes(deliveryOrder.status)) {
      return json({ error: `当前状态 ${deliveryOrder.status} 不可发单` }, 409);
    }
    // 7. 读取商家取货地址
    // merchant 的 SELECT 策略是公开可读（USING true），RLS 不构成归属校验，
    // 因此必须显式比对 user_id，否则任何登录用户都能拿别人的商家地址发单。
    const { data: merchant, error: merchantError } = await supabase.from('merchant').select().eq('id', deliveryOrder.merchant_id).maybeSingle();
    console.log(`merchant: ${JSON.stringify(merchant)}, merchantError: ${JSON.stringify(merchantError)}`);
    if (merchantError) {
      return json({ error: '读取商家失败', detail: merchantError.message }, 500);
    }
    if (!merchant) {
      return json({ error: '商家不存在' }, 404);
    }
    if (merchant.user_id !== user.user.id) {
      return json({ error: '无权为该商家发单' }, 403);
    }
    // 8. 组装 param（字段名严格按文档）
    // 寄件人 = 商家取货地址，收件人 = 配送单收货地址。
    // 商家点「呼叫骑手」时餐已备好，所以是立即单（orderType=0），不传预约时间。
    // thirdId 传我方配送单 UUID，作为回调对账的兜底标识。
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
      price: String(deliveryOrder.total_paid ?? 0),
      goods: [{ type: '食品', count: 1, name: deliveryOrder.meal_snapshot?.name ?? '外卖' }],
      thirdId: deliveryOrder.id,
      orderType: 0
    };
    // salt 随单发出，快递100 用它给回调签名。不传则回调无法验签，
    // 因此这里只判断「配没配」，没配就是部署失误，直接抛错而不是静默跳过。
    const salt = Deno.env.get('DELIVERY_CALLBACK_SALT');
    if (!salt) {
      throw new Error('缺少 DELIVERY_CALLBACK_SALT');
    }
    param.salt = salt;
    // callbackUrl 受快递100 文档 50 字符长度限制，而本项目函数 URL 前缀
    // （https://wmioylfpdbdwnbybkpju.supabase.co/functions/v1/）单独就 54 字符，
    // 拼上函数名必然超限。绕法见 supabase/config.toml：
    // 网关只按第一段路由，故用短 slug 的既有函数当跳板、真实目标放第二段。
    // 未配置时单仍可发出，只是拿不到状态回调。
    const callbackUrl = Deno.env.get('DELIVERY_CALLBACK_URL');
    if (callbackUrl) {
      param.callbackUrl = callbackUrl;
    } else {
      console.warn('未配置 DELIVERY_CALLBACK_URL，本单不会收到状态回调');
    }
    // 把最终 param 打出来：callbackUrl/salt 是否真的带上，只看日志才能确认，
    // 否则「回调没来」会被误判成快递100 的问题。
    console.log(`callbackUrl: ${callbackUrl ?? '(未配置)'}`);
    // 9. 发单
    const resp = await callKuaidi100(param);
    if (!resp.success || resp.code !== 200 || !resp.data?.orderId) {
      const reason = `${resp.code} ${resp.message}`;
      await supabase.from('meal_delivery_order').update({ dispatch_failed_reason: reason }).eq('id', deliveryOrder.id);
      return json({ error: '发单失败', code: resp.code, detail: resp.message }, 502);
    }
    // 10. 落库：记录第三方单号与成本，状态推进到 awaiting_delivery
    // discountFee 可能是 '' 或非数字，Number('') === 0 会写成假成本，需显式判空。
    const { taskId, orderId, discountFee } = resp.data;
    const providerFee = discountFee && Number.isFinite(Number(discountFee)) ? Number(discountFee) : null;
    const { error: updateError } = await supabase.from('meal_delivery_order').update({
      // 服务商标识由函数写入，表上没有默认值：将来换服务商时不必改表结构，
      // 由本函数决定写哪一家，也让「哪些单是快递100 发的」在库里可查。
      delivery_provider: 'kuaidi100',
      provider_task_id: taskId,
      provider_order_id: orderId,
      provider_status: 0,
      provider_status_desc: '下单成功',
      provider_fee: providerFee,
      dispatched_at: new Date().toISOString(),
      dispatch_failed_reason: null,
      status: 'awaiting_delivery',
      updated_at: new Date().toISOString()
    }).eq('id', deliveryOrder.id);
    console.log(`updateError: ${JSON.stringify(updateError)}`);
    // 真实单已发出但本地没记上号：这是最危险的状态，必须显式暴露出来，
    // 让调用方按 thirdId 去快递100 后台核对，而不是当成成功返回。
    if (updateError) {
      return json({
        error: '发单已成功但本地落库失败，请用 thirdId 核对后人工补录',
        third_id: deliveryOrder.id,
        provider_order_id: orderId,
        detail: updateError.message
      }, 500);
    }
    return json({
      provider_order_id: orderId,
      provider_task_id: taskId,
      provider_fee: providerFee,
      status: 'awaiting_delivery'
    });
  } catch (err) {
    // 兜住意外异常（body 非 JSON、header 缺失、字段访问越界、fetch 抛错等），
    // 保证前端永远拿到统一的 JSON，而不是 runtime 的裸 500。
    console.error(err);
    return json({ error: '服务器内部错误' }, 500);
  }
});
