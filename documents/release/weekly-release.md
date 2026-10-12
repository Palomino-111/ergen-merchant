# 商家端 Android 自动发版（GitHub Actions + 阿里云 OSS + 飞书）

> Workflow：`.github/workflows/weekly-release.yml`（单文件）
> 机制来源：消费端 `ergen-mobile-flutter` 的同一套流水线（含其 ADR-0001）。本文只记商家端的
> 落地差异与运维要点，设计理由（为什么私有 ACL、为什么 7 天签名链接、为什么版本号取日期）
> 见消费端仓库 `docs/adr/0001-android-release-pipeline.md`。

每周五 08:30（北京时间）自动构建 release APK → 上传阿里云 OSS → 把**一条 7 天有效的签名下载链接**发到飞书群。

> ⚠️ **APK 是私有的，没有公开链接。** 封闭测试阶段安装包不能被匿名扫到/下载。
> 代价是签名链接最长只能 7 天（OSS V4 签名的硬上限），**以群里最新一条消息为准**。

---

## 1. 每周会发生什么

| 时间       | 动作                                                                          |
| ---------- | ----------------------------------------------------------------------------- |
| 周五 08:30 | 触发（GitHub 定时任务是 best-effort，高峰期可能延迟几分钟到几十分钟）         |
| +0~5 秒    | **配置自检**：缺 Variable / Secret 立刻失败，不会白等 30 分钟构建             |
| +0~1 min   | 装 JDK 17 / Android SDK 35 / NDK 26.1.10909125 / Flutter 3.27.4 / ossutil 2.4.0 |
| +5~20 min  | `flutter build apk --release`（universal APK）                                |
| +1~2 min   | 上传归档对象 → 覆盖 `latest.apk` → **确认匿名直连被拒** → 生成 7 天签名链接并验证 |
| +几秒      | 飞书群收到消息（链接 7 天后过期）                                             |

失败时**不会**发飞书（刻意取舍，见 §7）。

---

## 2. 版本号

|             | 规则                            |
| ----------- | ------------------------------- |
| versionName | `0.0.<YYMMDD>`，如 `0.0.260918` |
| versionCode | `<YYMMDD>`，如 `20260918`       |

两者都由**构建日期**（北京时间）派生，不回写 `pubspec.yaml`、不打 tag、CI 只有 `contents: read`。

- versionCode 单调递增 → 覆盖安装不会 `INSTALL_FAILED_VERSION_DOWNGRADE`。
- `pubspec.yaml` 里的 `version: 0.0.1+1` 对 CI 构建**不起作用**（被 `--build-name/--build-number` 覆盖），
  它只影响本地 `flutter run` / 本地构建。
- 同一天重复跑（手动重跑）会得到同一个版本号，**归档对象会被同名覆盖**。介意的话换个日期再发。

---

## 3. OSS 上的结构

bucket：`hk-ergen`（**香港**节点，地域 `cn-hongkong`），自定义域名：`dl.guying.xyz`（已绑定 + 已配证书）。

```
ergen-merchant/                            ← OSS_PREFIX
├── latest.apk                             ← 当前版本，ACL 私有；每次发版覆盖
└── releases/
    └── zheergen-merchant-0.0.260918.apk   ← 版本归档，ACL 私有；只用于追溯/回滚
```

**两个对象都是私有的，没有任何公开可访问的 URL。** 用户拿到的是一条签名链接：

```
https://dl.guying.xyz/ergen-merchant/latest.apk?x-oss-credential=...&x-oss-expires=604800&x-oss-signature=...
```

- 路径部分**每周都一样**，变的只是签名参数；有效期 7 天（`ossutil presign --expires-duration 168h`）。
- **不要**把链接贴到任何长期物料上（二维码、落地页、README、客服话术）。
- 商家端是**香港** bucket + 自定义域名，所以 ossutil 必须带 `--addressing-style cname`，
  链接域名就是 `dl.guying.xyz`；换成默认地域节点 `hk-ergen.oss-cn-hongkong.aliyuncs.com`
  下载会 400 `ApkDownloadForbidden`（该限制**只管下载不管上传**，cp 会成功、点链接才报错）。

---

## 4. 一次性配置

### 4.1 默认分支必须收敛（否则定时任务一次都不会触发）

GitHub 官方限制：`schedule` **只在仓库默认分支上生效**。本仓库默认分支曾是 `main`，
而实际开发/发布分支是 `develop_mvp`（领先 main 11 个提交），两者必须收敛，二选一：

- **方案 A（与消费端一致，推荐）**：`Settings → General → Default branch → 切到 develop_mvp`。
  好处是「构建的代码」与「执行的定义」天然同源，workflow 改了立即对定时任务生效。
- 方案 B：把 `develop_mvp` 合进 `main`（当前 main 无独有提交，可快进），保持 main 为默认分支。
  代价是以后每次改 workflow 都要额外合一次。

改完本地刷引用：`git remote set-head origin -a`。

### 4.2 OSS 侧

1. **建议建一个 RAM 子账号**，别用主账号 AccessKey。最小权限策略：

   ```json
   {
     "Version": "1",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": ["oss:PutObject", "oss:GetObject", "oss:GetObjectMeta", "oss:ListObjects"],
         "Resource": ["acs:oss:*:*:hk-ergen/ergen-merchant/*"]
       }
     ]
   }
   ```

2. **保持私有，不要开公共读**。bucket ACL 私有；流水线对每个对象显式打 `--acl private`。
   本 bucket 已开启「阻止公共访问」（`--acl public-read` 会被拒，`Ec=0016-00000901`），这是好事：
   签名链接是带签名的认证请求、不是匿名请求，不受它影响。
3. 自定义域名 `dl.guying.xyz` 已绑定并配好证书（HTTPS 正常）。**CNAME 记录保持"仅 DNS"（灰云）**，
   不要开 Cloudflare 橙云代理（免费版代理大文件有 ToS/限速风险）。

### 4.3 GitHub Variables（`Settings → Secrets and variables → Actions → Variables`）

| 名称           | 值                            | 说明                                     |
| -------------- | ----------------------------- | ---------------------------------------- |
| `OSS_BUCKET`   | `hk-ergen`                    |                                          |
| `OSS_ENDPOINT` | `dl.guying.xyz`               | **自定义域名**，不带协议（cname 寻址用） |
| `OSS_REGION`   | `cn-hongkong`                 | ossutil 2.x 的 V4 签名必填               |
| `OSS_PREFIX`   | 默认 `ergen-merchant`         | 可覆盖                                   |
| `OSS_ADDRESSING_STYLE` | 默认 `cname`          | 置空可去掉该参数（逃生口）               |

### 4.4 GitHub Secrets

| 名称                    | 必填 | 说明                                        |
| ----------------------- | ---- | ------------------------------------------- |
| `OSS_ACCESS_KEY_ID`     | ✅    | RAM 子账号 AK                               |
| `OSS_ACCESS_KEY_SECRET` | ✅    | 对应 SK                                     |
| `FEISHU_WEBHOOK_URL`    | ✅    | 飞书机器人 webhook                          |
| `FEISHU_BOT_SECRET`     |      | 机器人开了「签名校验」时必填（本项目已开）  |

> Variables 与 Secrets 是**两个不同的存储**，`vars.X` 读不到 Secrets 里的同名项。
> 混放的表现就是「明明配了却是空的」。

### 4.5 飞书机器人

群设置 → 群机器人 → 添加机器人 → **自定义机器人** → 安全设置选 **签名校验** → webhook 与密钥
分别填进 `FEISHU_WEBHOOK_URL` / `FEISHU_BOT_SECRET`。

- ⚠️ **不要用 IP 白名单**：GitHub 托管 runner 出网 IP 是动态的，必然 `19022`。
- 用「自定义关键词」也行，关键词要出现在消息里。

---

## 5. 手动触发

```
Actions → Android Weekly Release → Run workflow
```

`dry_run` **默认勾选**（只构建、不上传、不通知），用来验证构建链路；确要认真发布时取消勾选。
定时任务恒为正式发布。

---

## 6. 回滚 / 临时补一条链接 / 本地应急

`release_feishu.sh` 已删除 —— 发布只有 CI 一条路径。以下是本地应急用的 ossutil 命令（**2.x 语法**）：

```bash
export OSS_ACCESS_KEY_ID=... OSS_ACCESS_KEY_SECRET=... OSS_REGION=cn-hongkong OSS_ENDPOINT=dl.guying.xyz

# ① 只补一条链接（不动包，几秒钟，不用等 CI）
ossutil presign oss://hk-ergen/ergen-merchant/latest.apk \
  --expires-duration 168h --addressing-style cname

# ② 把某个好版本覆盖回 latest.apk（回滚）
ossutil cp oss://hk-ergen/ergen-merchant/releases/zheergen-merchant-<好版本>.apk \
           oss://hk-ergen/ergen-merchant/latest.apk -f \
  --acl private \
  --content-type application/vnd.android.package-archive \
  --content-disposition 'attachment; filename=zheergen-merchant-<好版本>.apk' \
  --cache-control 'private, no-store' \
  --addressing-style cname
```

**不要覆盖已发出去的归档对象** —— 它是唯一的追溯凭据；修复版换个日期重发即可。

---

## 7. 为什么失败不发飞书

通知逻辑只保留「发送」本身，少一个 job、少一半代码。代价是「这周没收到消息」需要自己去
Actions 页确认是没触发还是构建挂了。要加回来就是再加一个 `needs: release` + `if: always()` 的 job。

---

## 8. 排错

| 症状                                           | 原因 / 处理                                                                                                                              |
| ---------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| 定时任务没触发                                 | 默认分支还不是 `develop_mvp`（或改动没合进默认分支）。见 §4.1                                                                            |
| `::error::缺少配置：Variable OSS_ENDPOINT`     | 配置自检拦下的（在**构建之前**）。Variables / Secrets 是两个 tab，别放错                                                                 |
| `Error: region must be set in sign version 4`  | `OSS_REGION` 没配（ossutil 2.x 比 1.x 多的必填项）                                                                                       |
| `unknown flag: --meta` / `--jobs`              | 抄到了 ossutil **1.x** 的文档。2.x 是 `--content-type` / `--content-disposition` / `--cache-control`，`--jobs` 变单数 `--job`             |
| 下载 400 `ApkDownloadForbidden`                | 用默认地域节点访问安装包被拦。必须走 `dl.guying.xyz` + `--addressing-style cname`                                                        |
| `latest.apk 仍可匿名下载（HTTP 200）`          | 对象不是私有的：检查对象 ACL / bucket「阻止公共访问」                                                                                   |
| 签名链接 403                                   | 链接过期、`--expires-duration` 超 604800 秒上限、或 runner 时钟偏差                                                                      |
| `ossutil presign 没有产出链接`                 | `OSS_ENDPOINT` / `OSS_REGION` 不对，或 ossutil 版本不匹配                                                                                |
| 用户说链接点不开                               | ① 过期了（7 天）→ 让他看群里最新一条；② 被聊天软件截断 → 点整条消息                                                                      |
| 用户说 `AccessDenied`                          | 拿的是已过期的旧签名链接                                                                                                                 |
| 飞书 `19021`                                   | 签名不匹配：核对 `FEISHU_BOT_SECRET`（算法：`HMAC-SHA256(key="<ts>\n<secret>", msg=空)`）                                                  |
| 飞书 `19022` / `19024`                         | 机器人开了 IP 白名单 / 自定义关键词                                                                                                      |
| 构建报 `Failed to find package 'tools'`        | `android-actions/setup-android` 用了 v3 以下；必须 ≥ v4                                                                                  |

---

## 9. 与消费端的差异 & 已知取舍

| 项                  | 消费端                                     | 商家端                                                  |
| ------------------- | ------------------------------------------ | ------------------------------------------------------- |
| Bucket / 节点       | `guying60`，`cn-guangzhou`                 | `hk-ergen`，`cn-hongkong`（香港，免备案）               |
| 自定义域名          | 已绑定（主机名里含 bucket + 地域）         | `dl.guying.xyz`（语义化子域名，不暴露 bucket/地域）     |
| Flutter 版本来源    | 仓库 `.fvmrc`                              | workflow 里硬编码 `FLUTTER_VERSION`（本仓库没有 .fvmrc） |
| Shiply / Sentry     | 有（注入凭证 + 校验 APK 内是否含 appId）   | 无，构建命令朴素                                        |
| 签名 keystore       | 入库（历史原因，已决定不轮换）             | 入库（`android/app/zheergenMerchantEndKeystore`）       |
| 版本号              | `0.0.<YYMMDD>` / `<YYMMDD>`                | 同（照抄）                                              |

**刻意不做的事**（与消费端一致）：不校验 APK 包名/版本/签名，不写清单、不出报告、不回写仓库、不打 tag。
残余风险：若有人误改 `build.gradle` 的签名配置，CI 会绿灯放过一个签名不对的包。要补的话约 10 行，
放在「构建」与「上传」之间。

**与消费端不同的一个已知短板**：本仓库是 **public**，而 release keystore + 明文密码在仓库里
（`android/app/build.gradle`）。消费端已就同一问题做过决策（不轮换，理由见其文档）。
商家端目前 `0.0.1` 尚无真实用户，若要处理，最低成本方案是**把仓库改成 private** 或**现在轮换 keystore**。

---

## 10. 依据

- GitHub：`schedule` 只在默认分支生效 —
  <https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows>
- 阿里云：`ApkDownloadForbidden` 怎么处理 —
  <https://help.aliyun.com/zh/oss/what-to-do-with-apkdownloadforbidden-reporting-an-error>
- 阿里云：预签名 URL 有效期上限（V4 = 7 天）—
  <https://www.alibabacloud.com/help/zh/oss/user-guide/how-to-obtain-the-url-of-a-single-object-or-the-urls-of-multiple-objects>
- 阿里云：ossutil 2.x 安装 —
  <https://help.aliyun.com/zh/oss/install-ossutil2>
- 飞书：自定义机器人（签名校验 / 错误码）—
  <https://open.feishu.cn/document/client-docs/bot-v3/add-custom-bot>
