# moon-pay-sdk — 5 分钟演示走查

面向评委与贡献者的完整走查：构建、测试、运行，然后读代码。全程离线，不涉及真实凭证与资金。

## 1. 构建与测试（约 2 分钟）

```bash
git clone https://github.com/daqing/moon-pay-sdk
cd moon-pay-sdk
moon test
```

117 个测试、0 警告。测试套件包含：与 openssl 交叉验证的签名黄金向量、走真实 HTTP 的端到端回环测试，以及汇总的安全负面用例（重放、未知序列号、篡改、错误密钥、金额不符）。

## 2. 运行支付演示

```bash
moon run examples/payment_demo
```

演示程序会启动一个本地 mock 平台，用测试专用密钥走完两条流程：

- **微信支付**：走真实 HTTP 创建 Native（扫码）订单，接收签名加密回调并由 SDK 验签解密，最后返回 `SUCCESS` 应答。
- **支付宝**：生成签名的电脑网站收银台跳转，接收签名通知并与本地订单金额对账，最后返回 `success` 应答。

## 3. 代码导览

| 路径 | 内容 |
| --- | --- |
| `crypto/` | 经纯 MoonBit 密码学栈（mooncrypt/mooncred/moonbase）的 RSA-SHA256、X.509 与 AES-256-GCM，全部与 `openssl` 参考签名交叉验证 |
| `transport/` | 基于 `moonbitlang/async` HTTP(S) 的 `Transport` 接口，以及让所有客户端测试离线可跑的可编程 mock |
| `wechat/` | 微信支付 v3 客户端：请求签名、Native/H5 下单、查单、平台证书、回调验签与解密 |
| `alipay/` | 支付宝开放平台客户端：规范串签名、page/wap 跳转、查单、通知与 `return_url` 验签 |
| `e2e/` | 回环端到端测试与汇总的安全负面用例 |

## 4. 可选：支付宝沙箱

使用真实沙箱凭证时，`cmd/sandbox` 会构造签名沙箱收银台 URL——见 `cmd/sandbox/README.md`。
