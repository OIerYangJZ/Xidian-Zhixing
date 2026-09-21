# 校园设计稿

入口：`index.html#campus`。桌面主导航与移动端左侧抽屉均有校园入口；现有移动端五项底部导航保持不变。

## 已检查的业务逻辑

- `flutter_app/lib/features/campus/campus_page.dart`：服务目录与今日日程并行加载，过滤无业务动作的服务，按服务分组；日程按来源进入课表、考试或实验。地图进入校方 GIS，外部服务使用目录动作链接。
- `flutter_app/lib/features/campus/campus_service_detail_page.dart`：课表及实验采用周历，考试请求 31 天并使用考试列表；过滤纯通知与重复日历动作。
- `flutter_app/lib/repositories/campus_repository.dart`：服务、日程、日历查询；校园网通过账号、密码和图形验证码认证，水机通过手机号、图形验证码和短信认证。
- `flutter_app/lib/core/l10n/campus_text.dart` 与 `backend/services/_db_service.py`：服务名称、四类分组和业务说明。

## 本次设计范围

同宽单栏校园首页、日程未同步状态、分类服务列表、双语搜索、周历日期浏览、独立认证预览、服务详情与官方地图入口。34 个目录入口支持中英文；字体、颜色与浅深模式使用现有设计变量。

仅修改 HTML 设计稿，未修改 Flutter、小程序或后端。登录预览不提交或存储凭据；无模拟登录成功。周历为日期导航预览，未接入真实日程；考试暂与周历共用预览，尚未绘制正式版的 31 天考试列表。外部服务除已知官方地图外仅展示入口说明，未擅自补造校方链接。离线小游戏保留原版点击计数交互。

已做脚本语法检查，未做浏览器视觉验收。
