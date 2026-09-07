"""
backend/_globals.py

Module-level runtime state and configuration constants.
Imported by helpers, services, and server.py.
server.py must call _globals.configure() early to populate all constants.

Why: avoids circular import issues between helpers and services.
"""

from __future__ import annotations

import importlib
import ipaddress
import os
import re
import threading
from collections import deque
from pathlib import Path
from typing import Any

# ---------------------------------------------------------------------------
# Runtime state (set by server.py at startup)
# ---------------------------------------------------------------------------

ADMIN_SESSIONS: dict[str, str] = {}
# token -> monotonic-ish issue time, so admin sessions can age out.  Kept
# alongside ADMIN_SESSIONS rather than inside it to preserve that dict's shape.
ADMIN_SESSION_ISSUED_AT: dict[str, float] = {}
ADMIN_SESSION_MAX_AGE_SECONDS = 12 * 3600
ADMIN_SESSION_LOCK = threading.Lock()

RATE_LIMIT_EVENTS: dict[tuple[str, str], deque[float]] = {}
RATE_LIMIT_LOCK = threading.Lock()

IP_RATE_LIMIT_EVENTS: dict[str, dict[str, deque[float]]] = {}
IP_RATE_LIMIT_LOCK = threading.Lock()

# Paths (set by configure())
ROOT_DIR: Path | None = None
DATA_DIR: Path | None = None
LEGACY_DB_FILE: Path | None = None
SQL_DB_FILE: Path | None = None
OBJECT_STORAGE_DIR: Path | None = None
WEB_ROOT_DIR: Path | None = None
DB_LOCK: threading.Lock | None = None
REPOSITORY: Any = None
OBJECT_STORAGE: Any = None

# SMTP state (set by configure_smtp())
_smtp_host: str = ""
_smtp_port: int = 0
_smtp_from_email: str = ""


def smtp_configured() -> bool:
    return bool(_smtp_host and _smtp_port > 0 and _smtp_from_email)


def verify_code_debug_enabled() -> bool:
    return ALLOW_DEBUG_VERIFY_CODE


def normalize_auth_email(value: str | None) -> str:
    """Canonical email representation for auth, allowlists, and persistence."""
    return str(value or "").strip().lower()


# ---------------------------------------------------------------------------
# Config constants (set by configure())
# ---------------------------------------------------------------------------

DEFAULT_CHANNELS: list[str] = []
DEFAULT_TAGS: list[str] = []
DEFAULT_SETTINGS: dict[str, Any] = {}
DEFAULT_SENSITIVE_WORDS: list[str] = []
SEED_POSTS: list[dict[str, Any]] = []
SEED_DEMO_DATA: bool = True

DEMO_USER_ID: str = "u1"
DEMO_USER_EMAIL: str = "demo@stu.xidian.edu.cn"
DEMO_USER_PASSWORD: str = "123456"

PASSWORD_HASH_SCHEME: str = "pbkdf2_sha256"
PASSWORD_HASH_ITERATIONS: int = 240000
PASSWORD_SALT_BYTES: int = 16

ADMIN_USERNAME_SETTING_KEY: str = "adminUsername"
ADMIN_PASSWORD_HASH_SETTING_KEY: str = "adminPasswordHash"
DEFAULT_ADMIN_USERNAME: str = "admin"
DEFAULT_ADMIN_PASSWORD: str = ""
ADMIN_ROLE_PRIMARY: str = "primary"
ADMIN_ROLE_SECONDARY: str = "secondary"
USER_LEVEL_ONE: int = 1
USER_LEVEL_TWO: int = 2

PIN_DURATION_OPTIONS: dict[int, str] = {}

SMTP_HOST: str = ""
SMTP_PORT: int = 465
SMTP_USERNAME: str = ""
SMTP_PASSWORD: str = ""
SMTP_FROM_EMAIL: str = ""
SMTP_FROM_NAME: str = "电台"
SMTP_USE_SSL: bool = True
SMTP_USE_STARTTLS: bool = False
BACKEND_XIDIAN_PUBLIC_ORIGIN: str = ""
ENABLE_XIDIAN_AUTH: bool = False
XIDIAN_AUTHORIZED_PUBLIC_ORIGIN = "https://zhixing.xidian.edu.cn"
CORS_ALLOWED_ORIGINS: set[str] = set()
AUTH_ALLOWED_STUDENT_IDS: set[str] = set()
# Server-owned authorization map.  The editable profile `college` field is
# display-only and must never grant access to a college section.
AUTH_STUDENT_COLLEGE_SECTIONS: dict[str, str] = {}
MAX_REQUEST_BODY_BYTES: int = 20 * 1024 * 1024

# Only peers inside these networks may set X-Forwarded-For / X-Real-IP.  An
# empty set means "trust nobody", so the raw socket peer is always used.
TRUSTED_PROXY_NETWORKS: list[ipaddress.IPv4Network | ipaddress.IPv6Network] = []

# AI provider configuration is server-only.  Never send these values to a
# client or accept them from an AI request body.
AI_BASE_URL: str = ""
AI_API_KEY: str = ""
AI_MODEL: str = "gpt-4o-mini"
AI_EMBEDDING_MODEL: str = ""

ALLOW_DEBUG_VERIFY_CODE: bool = False
INCLUDE_DEBUG_CODE_IN_RESPONSE: bool = False
PASSWORD_RESET_CODE_PREFIX: str = "reset::"

RATE_LIMIT_WINDOWS_SECONDS: dict[str, int] = {}
IP_RATE_LIMITS: dict[str, dict[str, Any]] = {}
ALLOWED_IMAGE_TYPES: set[str] = set()

RATE_LIMIT_EVENT_MAX = 300
RATE_LIMIT_SUBJECT_MAX = 20_000
NOTIFICATION_MAX_PER_USER = 500
SPAM_REPEAT_REGEX: re.Pattern | None = None
ADMIN_MIN_PASSWORD_LENGTH = 12
UNSAFE_ADMIN_PASSWORDS = frozenset({
    "admin123456",
    "change-me-now",
    "replace-me",
    "changeme",
})

BACKEND_VERSION: str = "0.2"


def admin_password_policy_error(password: str) -> str:
    if len(password) < ADMIN_MIN_PASSWORD_LENGTH:
        return f"密码长度至少 {ADMIN_MIN_PASSWORD_LENGTH} 位"
    if password.lower() in UNSAFE_ADMIN_PASSWORDS:
        return "密码不能使用已知默认值或占位值"
    return ""


def configure() -> None:
    """Called by server.py at startup — populates all globals from environment."""
    global ROOT_DIR, DATA_DIR, LEGACY_DB_FILE, SQL_DB_FILE, \
        OBJECT_STORAGE_DIR, WEB_ROOT_DIR, DB_LOCK, REPOSITORY, OBJECT_STORAGE, \
        SMTP_HOST, SMTP_PORT, SMTP_USERNAME, SMTP_PASSWORD, \
        SMTP_FROM_EMAIL, SMTP_FROM_NAME, SMTP_USE_SSL, SMTP_USE_STARTTLS, \
        BACKEND_XIDIAN_PUBLIC_ORIGIN, ENABLE_XIDIAN_AUTH, CORS_ALLOWED_ORIGINS, \
        AUTH_ALLOWED_STUDENT_IDS, AUTH_STUDENT_COLLEGE_SECTIONS, \
        MAX_REQUEST_BODY_BYTES, TRUSTED_PROXY_NETWORKS, \
        DEFAULT_ADMIN_USERNAME, DEFAULT_ADMIN_PASSWORD, \
        AI_BASE_URL, AI_API_KEY, AI_MODEL, AI_EMBEDDING_MODEL, \
        ALLOW_DEBUG_VERIFY_CODE, INCLUDE_DEBUG_CODE_IN_RESPONSE, \
        DEFAULT_CHANNELS, DEFAULT_TAGS, DEFAULT_SETTINGS, \
        DEFAULT_SENSITIVE_WORDS, SEED_POSTS, SEED_DEMO_DATA, \
        PIN_DURATION_OPTIONS, RATE_LIMIT_WINDOWS_SECONDS, IP_RATE_LIMITS, \
        ALLOWED_IMAGE_TYPES, \
        _smtp_host, _smtp_port, _smtp_from_email

    runtime_env = os.environ.get("BACKEND_ENV", "development").strip().lower()
    configured_admin_username = os.environ.get("BACKEND_ADMIN_USERNAME", "").strip()
    configured_admin_password = os.environ.get("BACKEND_ADMIN_PASSWORD", "").strip()
    if not configured_admin_password:
        raise RuntimeError("BACKEND_ADMIN_PASSWORD is required")
    if configured_admin_password.lower() in UNSAFE_ADMIN_PASSWORDS:
        raise RuntimeError("BACKEND_ADMIN_PASSWORD must not use a known placeholder or default value")
    if runtime_env == "production":
        if not configured_admin_username:
            raise RuntimeError("BACKEND_ADMIN_USERNAME is required in production")
        if admin_password_policy_error(configured_admin_password):
            raise RuntimeError(
                "BACKEND_ADMIN_PASSWORD must contain at least 12 characters in production"
            )
        if os.environ.get("BACKEND_SEED_DEMO_DATA", "false").strip().lower() in {"1", "true", "yes", "on"}:
            raise RuntimeError("BACKEND_SEED_DEMO_DATA must be false in production")
    DEFAULT_ADMIN_USERNAME = configured_admin_username or "admin"
    DEFAULT_ADMIN_PASSWORD = configured_admin_password
    SEED_DEMO_DATA = os.environ.get(
        "BACKEND_SEED_DEMO_DATA",
        "false" if runtime_env == "production" else "true",
    ).strip().lower() in {"1", "true", "yes", "on"}

    ROOT_DIR = Path(__file__).resolve().parent
    DATA_DIR = ROOT_DIR / "data"
    LEGACY_DB_FILE = DATA_DIR / "db.json"
    SQL_DB_FILE = Path(os.environ.get("BACKEND_DB_FILE", str(DATA_DIR / "treehole.db")))
    OBJECT_STORAGE_DIR = Path(os.environ.get("BACKEND_STORAGE_DIR", str(ROOT_DIR / "storage" / "objects")))
    WEB_ROOT_DIR = Path(os.environ.get("BACKEND_WEB_ROOT", str(ROOT_DIR.parent / "build" / "web"))).resolve()
    DB_LOCK = threading.Lock()

    global REPOSITORY, OBJECT_STORAGE
    from sql_repository import SqliteTreeholeRepository
    from object_storage import build_object_storage_from_env
    global _repository, _object_storage
    REPOSITORY = SqliteTreeholeRepository(SQL_DB_FILE)
    OBJECT_STORAGE = build_object_storage_from_env(
        local_root_dir=OBJECT_STORAGE_DIR,
        local_public_prefix="/api/storage",
    )

    DEFAULT_CHANNELS[:] = [
        "吐槽日常", "求助问答", "二手交易", "找搭子",
        "失物招领", "学习交流", "活动拼车", "交友扩列",
    ]
    DEFAULT_TAGS[:] = [
        "找对象", "找搭子", "交友扩列", "吐槽日常", "八卦吃瓜",
        "求助问答", "失物招领", "二手交易", "学习交流", "活动拼车",
        "学习", "北校区", "南校区", "运动", "周末",
        "食堂", "日常", "数码", "毕业季",
    ]
    DEFAULT_SETTINGS.clear()
    DEFAULT_SETTINGS.update({
        "postRateLimit": 5,
        "commentRateLimit": 20,
        "messageRateLimit": 30,
        "uploadRateLimit": 30,
        "imageMaxMB": 5,
        "reportRateLimit": 10,
        "dmRequestRateLimit": 20,
        "authLoginRateLimit": 10,
        "adminLoginRateLimit": 5,
        "verificationSendRateLimit": 3,
        "verificationCheckRateLimit": 10,
        "passwordResetRateLimit": 5,
        "appealRateLimit": 5,
        # Every one of these appends a permanent row and save_db rewrites the
        # whole database, so an unmetered caller is both a storage leak and an
        # O(database) amplifier.
        "clubApplicationRateLimit": 5,
        "feedbackRateLimit": 5,
        "pinRequestRateLimit": 10,
        "campusAuthRateLimit": 20,
        "dormWaterSmsRateLimit": 3,
        "aiChatRateLimit": 30,
        "aiSearchRateLimit": 60,
        "interactionRateLimit": 60,
    })
    DEFAULT_SENSITIVE_WORDS[:] = ["引流", "广告", "辱骂", "诈骗"]

    SEED_POSTS[:] = [
        {"title": "求助：图书馆哪里插座最多？", "content": "这周赶大作业，想找一个相对安静而且插座多的位置，北校区优先。",
         "channel": "求助问答", "tags": ["求助问答", "学习", "北校区"], "hasImage": False, "status": "ongoing",
         "allowComment": True, "allowDm": True, "authorAlias": "洞主-青橙", "authorId": "seed-user-1"},
        {"title": "找周末羽毛球搭子", "content": "周六下午操场旁边羽毛球馆，水平一般，主打一起运动。",
         "channel": "找搭子", "tags": ["找搭子", "运动", "周末"], "hasImage": True, "status": "ongoing",
         "allowComment": True, "allowDm": True, "authorAlias": "洞主-极光", "authorId": "seed-user-1"},
        {"title": "二手显示器出一个 24 寸", "content": "毕业清东西，成色还不错，支持当面看货。",
         "channel": "二手交易", "tags": ["二手交易", "数码", "毕业季"], "hasImage": True, "status": "ongoing",
         "allowComment": True, "allowDm": True, "authorAlias": "洞主-小行星", "authorId": "seed-user-2"},
        {"title": "吐槽：食堂晚高峰排队太久", "content": "今天排了 25 分钟，想知道有没有错峰吃饭攻略。",
         "channel": "吐槽日常", "tags": ["吐槽日常", "食堂", "日常"], "hasImage": False, "status": "resolved",
         "allowComment": True, "allowDm": False, "authorAlias": "洞主-银杏", "authorId": "seed-user-2"},
    ]
    SEED_POSTS.extend([
        {"title": "南校区 B 楼 204 怎么走", "content": "从礼仪广场往教学区走，B 楼在 A 楼东侧、C 楼西侧。进楼后看二层连廊指示，B-204 在二层南侧。第一次去建议至少提前十分钟。", "channel": "求助问答", "tags": ["求助问答", "南校区", "教学楼"], "hasImage": False, "status": "resolved", "allowComment": True, "allowDm": False, "authorAlias": "洞主-银杏", "authorId": "seed-user-2"},
        {"title": "B 楼附近打印店实测", "content": "最近在 B 楼上课，临时打印可以先看教学区自助打印点；需要装订和彩印时可以去海棠附近的打印店。营业时间可能变化，晚上去前建议先确认。", "channel": "学习交流", "tags": ["学习", "南校区", "打印"], "hasImage": False, "status": "ongoing", "allowComment": True, "allowDm": False, "authorAlias": "洞主-青橙", "authorId": "seed-user-1"},
        {"title": "北校区图书馆插座座位经验", "content": "靠墙和柱子附近的座位插座相对集中，考试周很早就会坐满。馆内座位和开放时间以图书馆当天安排为准。", "channel": "学习交流", "tags": ["学习", "北校区", "图书馆"], "hasImage": False, "status": "resolved", "allowComment": True, "allowDm": False, "authorAlias": "洞主-小行星", "authorId": "seed-user-2"},
        {"title": "南校区图书馆研讨间预约提醒", "content": "研讨间通常需要在图书馆空间预约系统提前预约，到了以后按页面要求签到。临时取消记得释放，避免影响后续预约。", "channel": "学习交流", "tags": ["学习", "南校区", "图书馆"], "hasImage": False, "status": "resolved", "allowComment": True, "allowDm": False, "authorAlias": "洞主-青橙", "authorId": "seed-user-1"},
        {"title": "校园网突然断线排查记录", "content": "先看终端是否拿到校内 IP，再到校园网自服务检查账号状态、套餐和在线设备。多设备占用或余额异常时也可能掉线。", "channel": "求助问答", "tags": ["求助问答", "校园网", "数码"], "hasImage": False, "status": "resolved", "allowComment": True, "allowDm": False, "authorAlias": "洞主-极光", "authorId": "seed-user-1"},
        {"title": "校外访问数据库的申请经验", "content": "在校外访问校内资源时，可以先查信息网络技术中心的零信任或校外访问说明。申请通过后再按官方客户端和账号说明操作。", "channel": "学习交流", "tags": ["学习", "校园网", "图书馆"], "hasImage": False, "status": "resolved", "allowComment": True, "allowDm": False, "authorAlias": "洞主-银杏", "authorId": "seed-user-2"},
        {"title": "宿舍电费余额怎么看", "content": "宿舍电费查询时要确认校区、楼号和房间号，缴费完成后余额同步可能有短暂延迟。具体入口和账单以学校缴费系统为准。", "channel": "求助问答", "tags": ["求助问答", "宿舍", "缴费"], "hasImage": False, "status": "resolved", "allowComment": True, "allowDm": False, "authorAlias": "洞主-青橙", "authorId": "seed-user-1"},
        {"title": "海棠餐厅错峰时间分享", "content": "工作日中午十二点前后排队最明显，我一般十一点四十前或十二点四十后去。窗口开放情况每天可能不一样。", "channel": "吐槽日常", "tags": ["食堂", "南校区", "日常"], "hasImage": False, "status": "ongoing", "allowComment": True, "allowDm": False, "authorAlias": "洞主-小行星", "authorId": "seed-user-2"},
        {"title": "丁香餐厅早餐窗口记录", "content": "早课前七点多已经有早餐窗口开放，八点前人会比较集中。节假日开放窗口和时间可能调整。", "channel": "吐槽日常", "tags": ["食堂", "南校区", "日常"], "hasImage": False, "status": "ongoing", "allowComment": True, "allowDm": False, "authorAlias": "洞主-极光", "authorId": "seed-user-1"},
        {"title": "空闲教室查询别只看当天", "content": "空闲教室要同时选择校区、日期和节次，有临时调课时现场占用可能和系统不同。准备长时间自习前最好再看门口课表。", "channel": "学习交流", "tags": ["学习", "教室", "南校区"], "hasImage": False, "status": "resolved", "allowComment": True, "allowDm": False, "authorAlias": "洞主-银杏", "authorId": "seed-user-2"},
        {"title": "考试座位查询注意事项", "content": "考试安排出来后要核对校区、楼宇、考场和座位号，同名课程可能分多个考场。临近考试再确认一次是否调整。", "channel": "学习交流", "tags": ["学习", "考试", "教务"], "hasImage": False, "status": "resolved", "allowComment": True, "allowDm": False, "authorAlias": "洞主-青橙", "authorId": "seed-user-1"},
        {"title": "成绩单下载和用途", "content": "电子成绩单通常用于保研、出国和申请材料，下载前注意中英文版本、盖章方式和课程是否完整。正式用途以教务或档案部门说明为准。", "channel": "学习交流", "tags": ["学习", "成绩", "教务"], "hasImage": False, "status": "resolved", "allowComment": True, "allowDm": False, "authorAlias": "洞主-极光", "authorId": "seed-user-1"},
        {"title": "物理实验第一次选课提醒", "content": "选实验时要看实验名称、时间、地点和分组，部分项目还要求预习。实验系统账号规则和开放时间以当学期通知为准。", "channel": "学习交流", "tags": ["学习", "实验", "选课"], "hasImage": False, "status": "ongoing", "allowComment": True, "allowDm": False, "authorAlias": "洞主-小行星", "authorId": "seed-user-2"},
        {"title": "体测前需要带什么", "content": "一般要带校园卡或能核验身份的证件，穿适合运动的衣服和鞋。具体项目顺序、缓测和补测安排看体育部通知。", "channel": "求助问答", "tags": ["求助问答", "运动", "体测"], "hasImage": False, "status": "resolved", "allowComment": True, "allowDm": False, "authorAlias": "洞主-银杏", "authorId": "seed-user-2"},
        {"title": "校医院就诊时间经验", "content": "普通门诊和节假日安排可能不同，准备去之前先看校医院或学校当天通知。紧急情况直接联系急救，不要只依赖帖子经验。", "channel": "求助问答", "tags": ["求助问答", "校医院", "日常"], "hasImage": False, "status": "resolved", "allowComment": True, "allowDm": False, "authorAlias": "洞主-青橙", "authorId": "seed-user-1"},
        {"title": "宿舍报修流程记录", "content": "提交报修时把校区、楼栋、房间、故障位置和照片写清楚，后续在报修记录里看受理状态。涉及漏水或用电危险应及时联系值班人员。", "channel": "求助问答", "tags": ["求助问答", "宿舍", "报修"], "hasImage": False, "status": "resolved", "allowComment": True, "allowDm": False, "authorAlias": "洞主-极光", "authorId": "seed-user-1"},
        {"title": "校园卡丢失后的处理", "content": "发现校园卡丢失先通过官方校园卡服务挂失，再按学校说明补卡。涉及余额和身份凭证，不要把完整卡号发到公开帖子。", "channel": "失物招领", "tags": ["失物招领", "校园卡", "日常"], "hasImage": False, "status": "resolved", "allowComment": True, "allowDm": False, "authorAlias": "洞主-小行星", "authorId": "seed-user-2"},
        {"title": "南北校区通勤时间参考", "content": "跨校区办事要给交通和进校核验留足时间，早晚高峰差异较大。校车班次、停靠点和购票方式以学校最新通知为准。", "channel": "活动拼车", "tags": ["活动拼车", "北校区", "南校区"], "hasImage": False, "status": "ongoing", "allowComment": True, "allowDm": True, "authorAlias": "洞主-银杏", "authorId": "seed-user-2"},
        {"title": "保研材料准备清单交流", "content": "常见材料包括成绩单、排名证明、英语成绩、科研竞赛和个人陈述。不同学院的资格和时间节点差别很大，应以本学院当年通知为准。", "channel": "学习交流", "tags": ["学习", "保研", "学院"], "hasImage": False, "status": "ongoing", "allowComment": True, "allowDm": True, "authorAlias": "洞主-青橙", "authorId": "seed-user-1"},
        {"title": "奖学金申请经验汇总", "content": "申请前核对评定办法、成绩范围、综合素质材料和公示时间。帖子只能提供整理思路，最终条件看学院及学生工作部门通知。", "channel": "学习交流", "tags": ["学习", "奖学金", "学院"], "hasImage": False, "status": "ongoing", "allowComment": True, "allowDm": False, "authorAlias": "洞主-极光", "authorId": "seed-user-1"},
        {"title": "社团活动场地怎么申请", "content": "通常需要在规定系统或主管单位提交活动信息、时间、人数和场地需求，审批通过后再使用。大型活动还可能需要安全方案。", "channel": "求助问答", "tags": ["求助问答", "社团", "场地"], "hasImage": False, "status": "resolved", "allowComment": True, "allowDm": True, "authorAlias": "洞主-小行星", "authorId": "seed-user-2"},
        {"title": "毕业离校手续别漏这些", "content": "毕业季通常要关注图书归还、校园卡、宿舍、财务欠费、档案和证书领取。各学院安排不同，按离校系统和辅导员通知逐项完成。", "channel": "求助问答", "tags": ["求助问答", "毕业季", "手续"], "hasImage": False, "status": "ongoing", "allowComment": True, "allowDm": False, "authorAlias": "洞主-银杏", "authorId": "seed-user-2"},
        {"title": "失物招领信息怎么写更容易找回", "content": "写清丢失时间段、校区、大致地点和物品特征，证件类不要公开完整号码。找到物品后及时把帖子状态改为已解决。", "channel": "失物招领", "tags": ["失物招领", "日常", "求助问答"], "hasImage": False, "status": "resolved", "allowComment": True, "allowDm": True, "authorAlias": "洞主-青橙", "authorId": "seed-user-1"},
        {"title": "招聘会入场准备", "content": "参加校招双选会前准备简历、学生证和目标单位清单，提前看场地图和岗位要求。时间地点变化以就业信息网发布为准。", "channel": "学习交流", "tags": ["学习", "就业", "毕业季"], "hasImage": False, "status": "ongoing", "allowComment": True, "allowDm": True, "authorAlias": "洞主-极光", "authorId": "seed-user-1"},
    ])

    PIN_DURATION_OPTIONS.clear()
    PIN_DURATION_OPTIONS.update({
        30: "30 分钟", 60: "1 小时", 120: "2 小时", 180: "3 小时",
        1440: "1 天", 4320: "3 天",
    })

    RATE_LIMIT_WINDOWS_SECONDS.clear()
    RATE_LIMIT_WINDOWS_SECONDS.update({
        "post": 3600, "comment": 3600, "message": 3600,
        "report": 3600, "dm_request": 3600, "upload": 3600,
        "auth_login": 900,
        "admin_login": 900,
        "verification_send": 600,
        "verification_check": 600,
        "password_reset": 600,
        "appeal": 3600,
        "club_application": 3600,
        "feedback": 3600,
        "pin_request": 3600,
        "campus_auth": 900,
        "dorm_water_sms": 3600,
        "ai_chat": 3600,
        "ai_search": 3600,
        "interaction": 3600,
    })
    IP_RATE_LIMITS.clear()
    IP_RATE_LIMITS.update({
        "post": {"limit": 20, "window": 3600},
        "comment": {"limit": 40, "window": 3600},
        "message": {"limit": 60, "window": 3600},
        "upload": {"limit": 30, "window": 3600},
        "auth_login": {"limit": 30, "window": 900},
        "admin_login": {"limit": 10, "window": 900},
        "verification_send": {"limit": 10, "window": 3600},
        "verification_check": {"limit": 30, "window": 600},
        "password_reset": {"limit": 15, "window": 600},
        "appeal": {"limit": 15, "window": 3600},
        "club_application": {"limit": 15, "window": 3600},
        "feedback": {"limit": 15, "window": 3600},
        "pin_request": {"limit": 30, "window": 3600},
        "campus_auth": {"limit": 40, "window": 900},
        "ai_chat": {"limit": 60, "window": 3600},
        "ai_search": {"limit": 120, "window": 3600},
        "interaction": {"limit": 180, "window": 3600},
    })

    ALLOWED_IMAGE_TYPES.clear()
    ALLOWED_IMAGE_TYPES.update({"image/jpeg", "image/png", "image/webp", "image/gif"})

    global SPAM_REPEAT_REGEX
    SPAM_REPEAT_REGEX = re.compile(r"(.)\1{8,}", re.DOTALL)

    SMTP_HOST = os.environ.get("BACKEND_SMTP_HOST", "").strip()
    SMTP_PORT = int(os.environ.get("BACKEND_SMTP_PORT", "465") or "465")
    SMTP_USERNAME = os.environ.get("BACKEND_SMTP_USERNAME", "").strip()
    SMTP_PASSWORD = os.environ.get("BACKEND_SMTP_PASSWORD", "").strip()
    SMTP_FROM_EMAIL = os.environ.get("BACKEND_SMTP_FROM_EMAIL", SMTP_USERNAME).strip()
    SMTP_FROM_NAME = os.environ.get("BACKEND_SMTP_FROM_NAME", "电台").strip() or "电台"
    SMTP_USE_SSL = os.environ.get("BACKEND_SMTP_USE_SSL", "true").strip().lower() in {"1", "true", "yes", "on"}
    SMTP_USE_STARTTLS = os.environ.get("BACKEND_SMTP_USE_STARTTLS", "false").strip().lower() in {"1", "true", "yes", "on"}
    BACKEND_XIDIAN_PUBLIC_ORIGIN = os.environ.get("BACKEND_XIDIAN_PUBLIC_ORIGIN", "").strip().rstrip("/")
    ENABLE_XIDIAN_AUTH = os.environ.get(
        "BACKEND_ENABLE_XIDIAN_AUTH",
        "false",
    ).strip().lower() in {"1", "true", "yes", "on"}
    CORS_ALLOWED_ORIGINS.clear()
    CORS_ALLOWED_ORIGINS.update(
        origin.strip().rstrip("/")
        for origin in os.environ.get("BACKEND_CORS_ALLOWED_ORIGINS", "").split(",")
        if origin.strip()
    )
    AUTH_ALLOWED_STUDENT_IDS.clear()
    AUTH_ALLOWED_STUDENT_IDS.update(
        student_id.strip().lower()
        for student_id in os.environ.get(
            "BACKEND_AUTH_ALLOWED_STUDENT_IDS",
            "",
        ).split(",")
        if student_id.strip()
    )
    AUTH_STUDENT_COLLEGE_SECTIONS.clear()
    for assignment in os.environ.get(
        "BACKEND_AUTH_STUDENT_COLLEGE_SECTIONS",
        "",
    ).split(","):
        candidate = assignment.strip()
        if not candidate:
            continue
        student_id, separator, section_id = candidate.partition("=")
        student_id = student_id.strip().lower()
        section_id = section_id.strip()
        if (
            not separator
            or not re.fullmatch(r"[0-9A-Za-z]{6,20}", student_id)
            or not re.fullmatch(r"[0-9A-Za-z_-]{1,80}", section_id)
        ):
            raise RuntimeError(
                "BACKEND_AUTH_STUDENT_COLLEGE_SECTIONS must contain "
                "studentId=sectionId pairs"
            )
        AUTH_STUDENT_COLLEGE_SECTIONS[student_id] = section_id
    # Reverse-proxy trust boundary.  X-Forwarded-For is only honoured when the
    # direct peer is one of these networks; otherwise any client could forge
    # its own source address and bypass every IP-keyed rate limit.
    configured_proxies = os.environ.get(
        "BACKEND_TRUSTED_PROXY_NETWORKS",
        "127.0.0.1/32,::1/128,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16",
    )
    TRUSTED_PROXY_NETWORKS = []
    for entry in configured_proxies.split(","):
        candidate = entry.strip()
        if not candidate:
            continue
        try:
            TRUSTED_PROXY_NETWORKS.append(
                ipaddress.ip_network(candidate, strict=False),
            )
        except ValueError as error:
            raise RuntimeError(
                f"BACKEND_TRUSTED_PROXY_NETWORKS contains an invalid entry: {candidate}"
            ) from error

    try:
        max_request_body_mb = int(
            os.environ.get("BACKEND_MAX_REQUEST_BODY_MB", "20"),
        )
    except ValueError as error:
        raise RuntimeError("BACKEND_MAX_REQUEST_BODY_MB must be an integer") from error
    if not 1 <= max_request_body_mb <= 100:
        raise RuntimeError("BACKEND_MAX_REQUEST_BODY_MB must be between 1 and 100")
    MAX_REQUEST_BODY_BYTES = max_request_body_mb * 1024 * 1024

    if ENABLE_XIDIAN_AUTH:
        if not re.fullmatch(r"https://[^/?#]+", BACKEND_XIDIAN_PUBLIC_ORIGIN):
            raise RuntimeError(
                "BACKEND_XIDIAN_PUBLIC_ORIGIN is required and must be an HTTPS origin "
                "when Xidian authentication is enabled"
            )

    if runtime_env == "production":
        if not CORS_ALLOWED_ORIGINS:
            raise RuntimeError(
                "BACKEND_CORS_ALLOWED_ORIGINS is required in production"
            )
        invalid_origins = [
            origin
            for origin in CORS_ALLOWED_ORIGINS
            if not re.fullmatch(r"https://[^/?#]+", origin)
        ]
        if invalid_origins:
            raise RuntimeError(
                "BACKEND_CORS_ALLOWED_ORIGINS must contain HTTPS origins only"
            )
        if CORS_ALLOWED_ORIGINS != {XIDIAN_AUTHORIZED_PUBLIC_ORIGIN}:
            raise RuntimeError(
                "BACKEND_CORS_ALLOWED_ORIGINS must match the authorized production origin"
            )
        invalid_student_ids = [
            student_id
            for student_id in AUTH_ALLOWED_STUDENT_IDS
            if not re.fullmatch(r"[0-9A-Za-z]{6,20}", student_id)
        ]
        if invalid_student_ids:
            raise RuntimeError(
                "BACKEND_AUTH_ALLOWED_STUDENT_IDS must contain valid student IDs"
            )
        if not ENABLE_XIDIAN_AUTH:
            raise RuntimeError(
                "BACKEND_ENABLE_XIDIAN_AUTH must be true in production"
            )
        if BACKEND_XIDIAN_PUBLIC_ORIGIN != XIDIAN_AUTHORIZED_PUBLIC_ORIGIN:
            raise RuntimeError(
                "BACKEND_XIDIAN_PUBLIC_ORIGIN must match the IDS-authorized production origin"
            )
    AI_BASE_URL = os.environ.get("BACKEND_AI_BASE_URL", os.environ.get("AI_BASE_URL", "")).strip().rstrip("/")
    AI_API_KEY = os.environ.get("BACKEND_AI_API_KEY", os.environ.get("AI_API_KEY", "")).strip()
    AI_MODEL = os.environ.get("BACKEND_AI_MODEL", os.environ.get("AI_MODEL", "gpt-4o-mini")).strip() or "gpt-4o-mini"
    AI_EMBEDDING_MODEL = os.environ.get("BACKEND_AI_EMBEDDING_MODEL", os.environ.get("AI_EMBEDDING_MODEL", "")).strip()

    if runtime_env == "production" and (AI_BASE_URL or AI_API_KEY):
        if not AI_BASE_URL.startswith("https://"):
            raise RuntimeError("BACKEND_AI_BASE_URL must use HTTPS in production")
        if not AI_API_KEY or "REPLACE" in AI_API_KEY.upper() or "CHANGE" in AI_API_KEY.upper():
            raise RuntimeError("BACKEND_AI_API_KEY is missing or still a placeholder")
        if not AI_MODEL:
            raise RuntimeError("BACKEND_AI_MODEL is required when AI is enabled")

    _smtp_host = SMTP_HOST
    _smtp_port = SMTP_PORT
    _smtp_from_email = SMTP_FROM_EMAIL

    ALLOW_DEBUG_VERIFY_CODE = os.environ.get("BACKEND_ALLOW_DEBUG_VERIFY_CODE", "").strip().lower() in {"1", "true", "yes", "on"}
    INCLUDE_DEBUG_CODE_IN_RESPONSE = os.environ.get("BACKEND_INCLUDE_DEBUG_CODE", "").strip().lower() in {"1", "true", "yes", "on"}
    if runtime_env == "production" and (ALLOW_DEBUG_VERIFY_CODE or INCLUDE_DEBUG_CODE_IN_RESPONSE):
        raise RuntimeError("Verification debug flags must be disabled in production")

# Expose runtime state via module-level names for convenient access
# (these are set by configure())
#
# NOTE: Handlers call _globals.xxx() for helper functions that actually live
# in helpers/ or services/ sub-modules. We proxy them here to avoid having
# to update all handler import lines in one go.
def _lazy_proxy(name: str) -> Any:
    """Lazy-import proxy for helper functions that live in sub-modules."""
    import importlib
    if name in (
        "now_iso", "parse_iso", "now_utc",
        "sanitize_alias", "normalize_avatar_url", "hash_password", "verify_password",
        "is_campus_email", "is_valid_student_id", "random_code", "detect_image_type",
        "get_client_ip", "check_ip_rate_limit", "consume_rate_limit",
        "assess_text_risk", "check_duplicate_image_hash",
    ):
        mod = importlib.import_module("helpers")
    elif name in (
        "effective_post_allow_dm", "iso_to_time_text",
        "conversation_key_for_users",
    ):
        mod = importlib.import_module("services")
    else:
        raise AttributeError(f"module '_globals' has no attribute '{name}'")
    val = getattr(mod, name, None)
    if val is None:
        raise AttributeError(f"module '_globals' has no attribute '{name}'")
    return val


def __getattr__(name: str) -> Any:
    # Direct module-level attributes
    if name == "ADMIN_SESSIONS":
        return ADMIN_SESSIONS
    if name == "ADMIN_SESSION_LOCK":
        return ADMIN_SESSION_LOCK
    if name == "RATE_LIMIT_EVENTS":
        return RATE_LIMIT_EVENTS
    if name == "RATE_LIMIT_LOCK":
        return RATE_LIMIT_LOCK
    if name == "IP_RATE_LIMIT_EVENTS":
        return IP_RATE_LIMIT_EVENTS
    if name == "IP_RATE_LIMIT_LOCK":
        return IP_RATE_LIMIT_LOCK
    if name == "DB_LOCK":
        return DB_LOCK
    if name == "REPOSITORY":
        return REPOSITORY
    if name == "OBJECT_STORAGE":
        return OBJECT_STORAGE
    if name == "ROOT_DIR":
        return ROOT_DIR
    if name == "DATA_DIR":
        return DATA_DIR
    if name == "LEGACY_DB_FILE":
        return LEGACY_DB_FILE
    if name == "SQL_DB_FILE":
        return SQL_DB_FILE
    if name == "OBJECT_STORAGE_DIR":
        return OBJECT_STORAGE_DIR
    if name == "WEB_ROOT_DIR":
        return WEB_ROOT_DIR
    if name == "RATE_LIMIT_EVENT_MAX":
        return RATE_LIMIT_EVENT_MAX
    if name == "SPAM_REPEAT_REGEX":
        return SPAM_REPEAT_REGEX
    # Proxy helper functions called as _globals.xxx()
    return _lazy_proxy(name)


# ---------------------------------------------------------------------------
# Handler stubs — functions handlers call via _globals.xxx() but actually
# live in sub-modules or don't exist yet. Defined here for convenience.
# ---------------------------------------------------------------------------

def sort_posts_for_view(
    db: dict[str, Any],
    posts: list[dict[str, Any]],
    *,
    sort_by: str = "latest",
) -> list[dict[str, Any]]:
    """Sort posts for display. sort_by: latest | hot | oldest."""
    import math
    import time
    from helpers._datetime_helpers import parse_iso
    from services._user_service import is_post_pin_active

    def parse_time(value: Any) -> float:
        try:
            return parse_iso(str(value or "")).timestamp()
        except Exception:
            return 0.0

    def compare_latest_key(row: dict[str, Any]) -> tuple[str, str]:
        return (str(row.get("createdAt", "")), str(row.get("id", "")))

    def engagement_score(row: dict[str, Any]) -> int:
        likes = max(0, int(row.get("likeCount", 0) or 0))
        comments = max(0, int(row.get("commentCount", 0) or 0))
        favorites = max(0, int(row.get("favoriteCount", 0) or 0))
        views = min(500, max(0, int(row.get("viewCount", 0) or 0)))
        return (likes * 3) + (comments * 5) + (favorites * 2) + views

    def hot_score(row: dict[str, Any]) -> float:
        age_hours = max(1.0, abs(time.time() - parse_time(row.get("createdAt", ""))) / 3600.0)
        decay = math.pow(age_hours + 2.0, 0.85)
        created_tie_breaker = parse_time(row.get("createdAt", "")) / 1_000_000_000_000_000.0
        return (engagement_score(row) / decay) + created_tie_breaker

    active_pinned = [row for row in posts if is_post_pin_active(row)]
    normal_rows = [row for row in posts if not is_post_pin_active(row)]

    active_pinned.sort(
        key=lambda row: (
            str(row.get("pinStartedAt", "")),
            str(row.get("createdAt", "")),
            str(row.get("id", "")),
        ),
        reverse=True,
    )

    if sort_by == "hot":
        normal_rows.sort(
            key=lambda row: (
                hot_score(row),
                engagement_score(row),
                str(row.get("createdAt", "")),
                str(row.get("id", "")),
            ),
            reverse=True,
        )
    elif sort_by == "likes":
        normal_rows.sort(
            key=lambda row: (
                max(0, int(row.get("likeCount", 0) or 0)),
                str(row.get("createdAt", "")),
                str(row.get("id", "")),
            ),
            reverse=True,
        )
    elif sort_by == "oldest":
        normal_rows.sort(key=lambda row: compare_latest_key(row))
    else:  # latest
        normal_rows.sort(key=lambda row: compare_latest_key(row), reverse=True)

    return [*active_pinned, *normal_rows]


def get_image_max_bytes(db: dict[str, Any]) -> int:
    """Return max image upload size in bytes from settings."""
    settings = db.get("settings", {})
    if isinstance(settings, dict):
        mb = int(settings.get("imageMaxMB", 5))
    else:
        mb = 5
    return max(1024 * 1024, mb * 1024 * 1024)


def is_auth_student_id_allowed(student_id: str) -> bool:
    """Return whether a unified-auth identity may access the private beta."""
    if not AUTH_ALLOWED_STUDENT_IDS:
        return True
    return student_id.strip().lower() in AUTH_ALLOWED_STUDENT_IDS


def public_system_settings() -> dict[str, Any]:
    """Return public system settings. DEPRECATED: use services.public_system_settings(db)."""
    return {
        "channels": list(DEFAULT_CHANNELS),
        "tags": list(DEFAULT_TAGS),
        "settings": dict(DEFAULT_SETTINGS),
        "rateLimitRules": {
            "post": {"limit": 20, "window": 3600},
            "comment": {"limit": 40, "window": 3600},
            "message": {"limit": 60, "window": 3600},
            "upload": {"limit": 30, "window": 3600},
        },
    }

__all__ = [
    "ADMIN_SESSIONS", "ADMIN_SESSION_LOCK",
    "RATE_LIMIT_EVENTS", "RATE_LIMIT_LOCK",
    "IP_RATE_LIMIT_EVENTS", "IP_RATE_LIMIT_LOCK",
    "DB_LOCK", "REPOSITORY", "OBJECT_STORAGE",
    "ROOT_DIR", "DATA_DIR", "LEGACY_DB_FILE", "SQL_DB_FILE",
    "OBJECT_STORAGE_DIR", "WEB_ROOT_DIR",
    "configure", "smtp_configured", "verify_code_debug_enabled",
    "normalize_auth_email",
    "ALLOW_DEBUG_VERIFY_CODE", "INCLUDE_DEBUG_CODE_IN_RESPONSE",
    "DEFAULT_CHANNELS", "DEFAULT_TAGS", "DEFAULT_SETTINGS",
    "DEFAULT_SENSITIVE_WORDS", "SEED_POSTS", "SEED_DEMO_DATA",
    "DEMO_USER_ID", "DEMO_USER_EMAIL", "DEMO_USER_PASSWORD",
    "PASSWORD_HASH_SCHEME", "PASSWORD_HASH_ITERATIONS", "PASSWORD_SALT_BYTES",
    "ADMIN_USERNAME_SETTING_KEY", "ADMIN_PASSWORD_HASH_SETTING_KEY",
    "DEFAULT_ADMIN_USERNAME", "DEFAULT_ADMIN_PASSWORD",
    "ADMIN_MIN_PASSWORD_LENGTH", "UNSAFE_ADMIN_PASSWORDS", "admin_password_policy_error",
    "ADMIN_ROLE_PRIMARY", "ADMIN_ROLE_SECONDARY",
    "USER_LEVEL_ONE", "USER_LEVEL_TWO",
    "PIN_DURATION_OPTIONS",
    "SMTP_HOST", "SMTP_PORT", "SMTP_USERNAME", "SMTP_PASSWORD",
    "SMTP_FROM_EMAIL", "SMTP_FROM_NAME", "SMTP_USE_SSL", "SMTP_USE_STARTTLS",
    "BACKEND_XIDIAN_PUBLIC_ORIGIN", "ENABLE_XIDIAN_AUTH", "XIDIAN_AUTHORIZED_PUBLIC_ORIGIN",
    "CORS_ALLOWED_ORIGINS", "AUTH_ALLOWED_STUDENT_IDS",
    "AUTH_STUDENT_COLLEGE_SECTIONS", "MAX_REQUEST_BODY_BYTES",
    "TRUSTED_PROXY_NETWORKS",
    "is_auth_student_id_allowed",
    "PASSWORD_RESET_CODE_PREFIX",
    "RATE_LIMIT_WINDOWS_SECONDS", "IP_RATE_LIMITS", "ALLOWED_IMAGE_TYPES",
    "RATE_LIMIT_EVENT_MAX", "RATE_LIMIT_SUBJECT_MAX", "SPAM_REPEAT_REGEX",
    "NOTIFICATION_MAX_PER_USER",
    "BACKEND_VERSION",
]
