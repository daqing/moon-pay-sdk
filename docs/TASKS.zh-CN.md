# moon-pay-sdk — 开发任务清单

`moon-pay-sdk` 的分步开发计划，依据黑客松申报书和 README 所载范围制定。每个任务都有稳定编号（`T1.1`、`T2.3`……），方便跟踪进度，利用闲余时间逐个完成。

## 使用说明

- 按 `T1` → `T9` 的阶段大致顺序推进；跨阶段依赖会在任务中注明。阶段内任务按依赖关系排序。
- 每个任务包含编号、体量标签——`[S]` ≈ 2 小时以内、`[M]` ≈ 半天、`[L]` ≈ 一天以上（闲余时间的粗略估计）——描述和 **完成标准**。标了 `(optional)` 的任务可以推迟，不影响 v0.1 发布。
- 所有任务共享同一基线完成定义：`moon build` 和 `moon test` 通过，跑过 `moon fmt && moon info`，`.mbti` 的 diff 符合预期。
- 在 `develop` 分支上小步提交、勤提交；大约一个任务对应一次提交。
- 严禁提交真实的商户私钥、平台证书或 APIv3 密钥。测试用的密钥材料统一放在 `test_keys/`，仅用于测试。

## 参考资料

- MoonBit 文档 — <https://docs.moonbitlang.com>
- moonbitlang/async — <https://mooncakes.io/docs/#/moonbitlang/async>
- 微信支付 API v3 — <https://pay.weixin.qq.com/wiki/doc/apiv3/index.shtml>
- 支付宝开放平台 — <https://opendocs.alipay.com>

## T1 — 基础骨架

目标：包结构就位，工具链和 OpenSSL 链接跑通，CI 变绿。

- [x] **T1.1** `[S]` 拆分子包。
  创建 `crypto/`、`wechat/`、`alipay/` 三个包；共享类型（统一错误、配置结构、小工具函数）放在根包，供三个子包引用。这一步定下 README 架构一节承诺的包布局。
  **完成标准：** 所有包在 `native` 目标下编译通过，空骨架无编译错误。
- [x] **T1.2** `[S]` 引入 `moonbitlang/async` 并在 `moon.mod` 中固定版本。
  用一个 async 版 `main`（sleep 后打印）冒烟测试 native 工具链。
  **完成标准：** `moon run cmd/main` 在 native 下正常运行——证明 async 基于 OpenSSL 的 C 桩在本机可构建。
- [x] **T1.3** `[M]` 添加 GitHub Actions CI。
  在 Linux 和 macOS 上构建并测试（用 `apt`/`brew` 安装 OpenSSL 开发包）。
  **完成标准：** workflow 在两个系统上都跑绿 `moon build` 和 `moon test`。
- [x] **T1.4** `[S]` 补全 `moon.mod` 元信息（`description`、`keywords`）。
  **完成标准：** mooncakes.io 包页面显示出有意义的描述和关键词。

## T2 — 加密层（mooncrypt）

目标：两家平台需要的所有密码学原语，以纯 MoonBit API 收在 `crypto` 包里——不再自写 OpenSSL C FFI。构建在纯 MoonBit 密码学栈之上：算法在 `moonbitstack/mooncrypt`（RSA、AES-GCM、ASN.1），证书在 `moonbitstack/mooncred`（X.509），编解码在 `moonbitstack/moonbase`（base16/base64）。OpenSSL 只保留在 `moonbitlang/async` 内部，由它在运行时加载用于 TLS 传输。

- [x] **T2.1** `[S]` 依赖脚手架。
  引入并固定 `moonbitstack/mooncrypt@0.3.1`、`moonbitstack/mooncred@0.6.1`、`moonbitstack/moonbase@0.4.0`；在 `crypto` 包中引用。
  **完成标准：** 单元测试通过 `mooncrypt/rsa` 完成一次简单的签名/验签往返，证明依赖图在 native 下可构建。
- [x] **T2.2** `[M]` 密钥加载。
  用 `@x509.pem` 解码 PEM 信封（RFC 7468），再用 `@asn1` 的 TLV 原语走 PKCS#8 / PKCS#1 `RSAPrivateKey` DER 结构取出 (n, e, d)，构造 `@rsa.PrivateKey`；PEM 公钥（SubjectPublicKeyInfo）同样处理；绝不打印密钥内容。
  **完成标准：** 测试夹具能加载为可用密钥，畸形 PEM/DER 返回错误值而不是崩溃。
- [x] **T2.3** `[M]` RSA-SHA256 签名（`sign_rsa_sha256`）。
  用商户私钥对报文签名（`@rsa.PrivateKey::sign`，scheme=Pkcs1、digest=Sha256）——微信 v3 请求鉴权和支付宝 RSA2 共同的基础原语。
  **完成标准：** 本实现产出的签名能通过 `openssl dgst -sha256 -sign` 生成参考签名的交叉验证。
- [x] **T2.4** `[M]` RSA-SHA256 验签（`verify_rsa_sha256`）。
  **完成标准：** 有效签名通过；无效、被篡改、密钥不匹配分别以不同错误失败。
- [x] **T2.5** `[S]` X.509 证书解析。
  经 `@x509.parse` / `Spki::rsa`：从 PEM 证书提取 (a) RSA 公钥和 (b) 小写十六进制序列号——即微信 `Wechatpay-Serial` 请求头所用的形式。
  **完成标准：** 自签名测试证书的两个字段均可往返解析。
- [x] **T2.6** `[M]` AES-256-GCM 解密（`aes256_gcm_decrypt`）。
  微信 v3 回调场景：base64 密文末尾附加 16 字节 GCM tag，12 字节 nonce，可选关联数据——正是 `@gcm.Gcm::open` 期望的格式。
  **完成标准：** 参考向量解密结果一致；密文、tag、AAD 任一被篡改都能干净失败。
- [x] **T2.7** `[S]` 随机数：经 `@async/fs` 读取 `/dev/urandom`（Linux/macOS），`@base16` 做十六进制编码；文档记录备选方案 `@async/tls.rand_bytes`。
  **完成标准：** 长度与字符集单元测试通过。
- [x] **T2.8** `[S]` 错误映射：`@spec.Broken`、`@asn1.Refused` 及 base64 失败 → 类型化的 `CryptoError`。
  **完成标准：** `crypto` 包的公开函数不 panic、不 abort。
- [x] **T2.9** `[S]` `test_keys/` 下的测试夹具（商户密钥对、平台风格自签证书），并附上可复现它们的 openssl 命令序列文档。
  **完成标准：** 夹具已提交、明确标注仅用于测试，且再生流程可复现。

## T3 — 共享运行时与工具

目标：两家平台共用的传输与解析层。

- [x] **T3.1** `[M]` 传输抽象 + HTTPS 客户端。
  基于 `async/http` 定义一个小的 `Transport` 接口（method、URL、headers、body → status、headers、body），提供真实 HTTPS 实现和可脚本化的测试 mock。后续所有客户端只依赖接口而不直接发 HTTP，保证全部逻辑可离线测试。
  **完成标准：** 对本地回环服务器的一次请求能完整往返。
- [x] **T3.2** `[S]` 基于核心库 `@json` 的 JSON 辅助函数。
  带类型和友好错误信息的编解码帮助函数。
  **完成标准：** 往返单元测试通过，包括畸形输入的错误处理。
- [x] **T3.3** `[S]` 统一错误模型。
  平台错误 `ApiError{code, message, ...}`，外加网络 / 加密 / 配置等变体；所有公开函数返回 `Result` 风格值。
  **完成标准：** 错误构造与展示有单元测试。
- [x] **T3.4** `[S]` 配置结构与校验（`wechat.Config`、`alipay.Config`），gateway/基础 URL 可覆盖，便于接沙箱和 mock 服务器。
  **完成标准：** 非法配置被拒绝并给出明确信息。
- [x] **T3.5** `[S]` 金额与订单号辅助函数。
  微信金额用整数分；支付宝金额用两位小数的元字符串；两者的 `out_trade_no` 字符集/长度校验。
  **完成标准：** 边界用例（零、舍入、非法字符）单元测试通过。

## T4 — 微信支付 v3 客户端

目标：三个服务端 API，请求签名正确，全部可离线对接 mock 传输测试。

- [x] **T4.1** `[M]` 请求签名与 `Authorization` 头。
  规范串：`METHOD\nPATH?QUERY\nTIMESTAMP\nNONCE\nBODY\n`，方案 `WECHATPAY2-SHA256-RSA2048`，携带 `mchid`、`serial_no`、`timestamp`、`nonce_str`、`signature`。
  **完成标准：** golden vector 测试与 `openssl` 生成的参考签名一致。
- [x] **T4.2** `[M]` Native 下单：`POST /v3/pay/transactions/native`（appid、mchid、description、out_trade_no、notify_url、`amount.total` 单位分）→ 返回 `code_url` 用于生成二维码。
  **完成标准：** mock 传输测试断言请求 JSON 与请求头，并成功解析响应。
- [ ] **T4.3** `[M]` H5 下单：`POST /v3/pay/transactions/h5`，带 `scene_info.payer_client_ip` → 返回 `h5_url`。
  **完成标准：** mock 传输测试通过。
- [ ] **T4.4** `[M]` 查单：按 `out_trade_no` 和 `transaction_id` 查询 → 类型化结果，含 `trade_state` 枚举（SUCCESS、REFUND、NOTPAY、CLOSED、REVOKED、USERPAYING、PAYERROR）、金额、交易单号。
  **完成标准：** 覆盖全部状态及 `ORDER_NOT_EXIST` 错误映射。
- [ ] **T4.5** `[S]` `(optional)` 基于平台证书的 API 响应验签（依赖 T5.1）。若推迟，在文档中说明取舍。

## T5 — 微信回调处理

目标：回调端点能信任并解析微信推送的内容。

- [ ] **T5.1** `[L]` 平台证书管理器。
  `GET /v3/certificates`，解密 `encrypt_certificate`（用 APIv3 密钥做 AES-256-GCM），缓存 序列号 → 证书/公钥，回调或响应头出现未知序列号时自动刷新。
  **完成标准：** mock 传输测试覆盖拉取、解密、缓存命中、未知序列号触发刷新。
- [ ] **T5.2** `[M]` 回调验签。
  读取 `Wechatpay-Serial/-Timestamp/-Nonce/-Signature` 请求头，用平台公钥验证报文 `TIMESTAMP\nNONCE\nBODY\n`，时间戳超过可配置窗口（默认 5 分钟）即拒绝，防重放。
  **完成标准：** 有效、被篡改、重放的回调均有测试覆盖。
- [ ] **T5.3** `[M]` 报文解密与解析。
  通知信封（event_type、resource_type、resource.ciphertext/nonce/associated_data）→ AES-256-GCM 解密 → 类型化支付通知（out_trade_no、transaction_id、trade_state、金额、payer）。未知事件类型时保留原始解密 JSON 可访问。
  **完成标准：** 完整有效夹具可解密解析；密钥或 AAD 错误时给出明确错误。
- [ ] **T5.4** `[S]` 应答辅助：HTTP 200 + `{"code":"SUCCESS","message":"OK"}`，以及用于 4xx/5xx 应答的失败报文（触发微信重试机制）。
  **完成标准：** 两种应答均有快照测试。
- [ ] **T5.5** `[S]` 组合函数 `verify_callback(headers, body) -> Notification`——即 README 示例展示的 API。
  **完成标准：** README 示例能用真实 API 编译通过（若命名有偏差则同步更新 README）。

## T6 — 支付宝客户端与异步通知

目标：签名的跳转 URL、查单、可信的异步通知。

- [ ] **T6.1** `[M]` 参数引擎。
  系统参数（app_id、method、format、charset、sign_type=RSA2、timestamp、version、notify_url / return_url）+ `biz_content` JSON；规范串 = 参数按 key 排序、排除 `sign` 与 `sign_type`、以 `k=v&` 拼接；RSA2 签名。
  **完成标准：** golden vector 测试固定规范串与签名。
- [ ] **T6.2** `[S]` 跳转 URL 构造器，为 `gateway.do` GET 流程做百分号编码。
  **完成标准：** 编码单元测试通过。
- [ ] **T6.3** `[M]` `page_pay_url`（`alipay.trade.page.pay`）——电脑网站支付，与 README 示例一致。
  **完成标准：** 生成 URL 中的签名能用支付宝公钥验证通过（用沙箱或官方验签工具核对）。
- [ ] **T6.4** `[S]` `wap_pay_url`（`alipay.trade.wap.pay`）——手机网站支付。
  **完成标准：** 同 T6.3 的验证方式。
- [ ] **T6.5** `[M]` 查单（`alipay.trade.query`）：POST 表单到网关，验证响应 `sign`，映射 `trade_status`（WAIT_BUYER_PAY、TRADE_CLOSED、TRADE_SUCCESS、TRADE_FINISHED）。
  **完成标准：** mock 测试覆盖全部状态与错误映射（如 ACQ.TRADE_NOT_EXIST）。
- [ ] **T6.6** `[M]` 异步通知验签。
  解析 POST 表单参数，RSA2 验签（排除 `sign`/`sign_type`），产出类型化 `NotifyResult`（trade_status、out_trade_no、trade_no、total_amount、app_id、seller_id），并提供金额比对辅助函数，让业务侧能确认通知与本地订单一致。
  **完成标准：** 有效、被篡改、app_id 伪造的通知均有测试。
- [ ] **T6.7** `[S]` 应答辅助：返回纯文本 `success`——其他任何内容都会导致支付宝重试。
  **完成标准：** 单元测试固定应答体。
- [ ] **T6.8** `[S]` `(optional)` 电脑网站支付 `return_url` 的 GET 参数验签，复用 T6.6 的验签路径。

## T7 — 测试与加固

目标：让黑客松演示站得住脚的测试体系。

- [ ] **T7.1** `[M]` 加密层测试覆盖到高位，含失败路径（用 `moon coverage analyze` 查缺口）。
  **完成标准：** `crypto` 中未覆盖的行要么补测、要么有明确理由。
- [ ] **T7.2** `[M]` 两个客户端的 mock 传输测试套件：鉴权头 golden、响应解析、平台错误映射。
  **完成标准：** 每个公开客户端方法至少一条成功路径 + 一条错误路径测试。
- [ ] **T7.3** `[L]` 端到端回环测试。
  用 `async/http` 起本地 mock 平台服务器：微信流程 = 下单 → POST 签名回调 → 验签 + 解密 → 应答；支付宝流程 = 通知表单 → 验签 → 应答。全部使用 `test_keys/` 中的材料签名。
  **完成标准：** 两条流程都作为 `moon test` 用例通过。
- [ ] **T7.4** `[S]` 安全负面用例：重放回调（过期时间戳）、未知序列号、篡改签名或报文、错误 APIv3 密钥、支付宝金额不一致——每项都以独立、清晰的错误拒绝。
  **完成标准：** 每个用例都有测试。
- [ ] **T7.5** `[S]` 卫生检查：`moon fmt`、`moon info` 干净；`.mbti` 作为公开 API 面复核；公开 API 中不留 TODO/FIXME。
  **完成标准：** `moon info && moon fmt` 之后 `git diff` 为空。
- [ ] **T7.6** `[S]` `(optional)` 沙箱联调脚本，用环境变量守护，并附文档说明如何用真实沙箱凭证运行。

## T8 — 示例、文档与 v0.1 发布

目标：可交付的黑客松 v0.1。

- [ ] **T8.1** `[M]` `examples/` 演示应用。
  (a) 创建微信 Native 订单并打印二维码内容；(b) 起 HTTP 服务器暴露 `/callback/wechat` 和 `/notify/alipay`，对收到的通知验签并打印，按规范应答。
  **完成标准：** 示例能对着 T7.3 的 mock 平台端到端跑通。
- [ ] **T8.2** `[S]` 用实际 API 校对两份 README：修正有偏差的命名，一旦描述属实就移除"目标 API / 开发中"的提示。
  **完成标准：** README 中每段代码示例都与真实 API 一致；符号链接 `README.md` 展示相同内容。
- [ ] **T8.3** `[S]` 发布杂项：定稿 `moon.mod` 描述/关键词、发布说明、annotated tag `v0.1.0`（版本号变更与发布准备放进同一个 commit）。
  **完成标准：** 本地 tag 存在且指向发布提交。
- [ ] **T8.4** `[S]` `moon publish` 发布到 mooncakes.io。
  **完成标准：** 包页面正确渲染 `README.mbt.md`，且能通过 `moon add` 安装该版本。
- [ ] **T8.5** `[S]` `(optional)` 黑客松提交用的演示脚本或录屏。

## T9 — 延伸 / v0.1 之后

有意排除在 v0.1 之外（与 README roadmap 一致），列在这里给未来的工作安家。按预期价值排序。

- [ ] **T9.1** `[L]` 退款：微信 `/v3/refund/domestic/refunds` 及退款状态通知；支付宝 `alipay.trade.refund` 与 `alipay.trade.fastpay.refund.query`。
- [ ] **T9.2** `[M]` 对账单下载：微信 tradebill 系列接口；支付宝对账单查询 API。
- [ ] **T9.3** `[M]` JSAPI / 小程序支付：prepay_id + paySign，面向微信内流程。
- [ ] **T9.4** `[M]` 两家的 APP 支付。
- [ ] **T9.5** `[S]` 微信公钥模式（新的免证书方案），作为平台证书的替代。
- [ ] **T9.6** `[S]` 发布自动化：tag 触发的发布 workflow、CI/覆盖率徽章。
