# myvideoserver

基于 **Python (FastAPI) + PostgreSQL + Nginx** 的浏览器端 HLS 流媒体点播服务，支持多视频管理和断点续播。

---

## 目录结构

```text
myvideoserver/
├── app/                  # FastAPI 后端
│   ├── __init__.py
│   ├── main.py           # 路由与应用入口
│   ├── db.py             # SQLAlchemy 引擎与会话
│   ├── models.py         # ORM 模型
│   └── schemas.py        # Pydantic 模型
├── frontend/
│   └── index.html        # 前端单页面（hls.js 播放器）
├── nginx/
│   └── video.conf        # Nginx 配置文件
├── scripts/
│   └── transcode_hls.sh  # FFmpeg HLS 转码脚本
├── sql/
│   └── init.sql          # 建表 DDL + demo 数据
├── requirements.txt
└── README.md
```

---

## 快速启动

### 1. 环境准备

```bash
# 安装系统依赖（以 Ubuntu/Debian 为例）
sudo apt update
sudo apt install -y python3 python3-pip python3-venv postgresql nginx ffmpeg
```

### 2. 初始化数据库

```bash
# 创建数据库和用户
sudo -u postgres psql -c "CREATE USER video_user WITH PASSWORD 'video_pass';"
sudo -u postgres psql -c "CREATE DATABASE video_db OWNER video_user;"

# 执行初始化 SQL（建表 + 插入 demo 数据）
psql -U video_user -d video_db -f sql/init.sql
```

### 3. 安装 Python 依赖

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 4. 配置环境变量（可选）

默认数据库连接串为 `postgresql+psycopg2://video_user:video_pass@127.0.0.1:5432/video_db`，可通过环境变量覆盖：

```bash
export DATABASE_URL="postgresql+psycopg2://video_user:video_pass@127.0.0.1:5432/video_db"
```

### 5. 启动后端服务

```bash
uvicorn app.main:app --host 127.0.0.1 --port 8000
```

### 6. 转码演示视频

```bash
chmod +x scripts/transcode_hls.sh

# 将 sample.mp4 转码为 HLS 切片，输出至 /data/hls/demo/
./scripts/transcode_hls.sh sample.mp4 /data/hls/demo
```

转码完成后，将视频记录写入数据库：

```sql
INSERT INTO videos (title, hls_path, duration_seconds)
VALUES ('Demo Video', '/hls/demo/index.m3u8', 60);
```

### 7. 配置 Nginx

```bash
# 将前端页面复制到 Nginx 根目录
sudo cp frontend/index.html /var/www/html/

# 应用 Nginx 配置
sudo cp nginx/video.conf /etc/nginx/conf.d/video.conf
sudo nginx -t && sudo systemctl reload nginx
```

### 8. 打开浏览器

访问 `http://localhost`，即可看到视频列表和播放界面。

---

## 接口说明

| 方法 | 路径 | 说明 |
|------|------|------|
| GET  | `/api/health` | 健康检查 |
| GET  | `/api/videos` | 获取视频列表 |
| GET  | `/api/videos/{video_id}/play` | 获取播放地址 + 上次进度 |
| POST | `/api/videos/{video_id}/progress` | 保存播放进度 |

### `/api/videos/{video_id}/play` 响应示例

```json
{
  "videoId": 1,
  "title": "Demo Video",
  "playUrl": "/hls/demo/index.m3u8",
  "lastProgressSeconds": 42,
  "durationSeconds": 60
}
```

### `/api/videos/{video_id}/progress` 请求示例

```json
{
  "progressSeconds": 42,
  "durationSeconds": 60
}
```

---

## 数据库表结构

```sql
-- 用户表
CREATE TABLE users (
    id         BIGSERIAL    PRIMARY KEY,
    username   VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- 视频资源表
CREATE TABLE videos (
    id               BIGSERIAL    PRIMARY KEY,
    title            VARCHAR(255) NOT NULL,
    hls_path         VARCHAR(500) NOT NULL,
    duration_seconds INTEGER      NOT NULL DEFAULT 0,
    created_at       TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- 播放进度表
CREATE TABLE video_play_progress (
    id               BIGSERIAL PRIMARY KEY,
    user_id          BIGINT    NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
    video_id         BIGINT    NOT NULL REFERENCES videos(id) ON DELETE CASCADE,
    progress_seconds INTEGER   NOT NULL DEFAULT 0,
    duration_seconds INTEGER   NOT NULL DEFAULT 0,
    created_at       TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_user_video UNIQUE (user_id, video_id)
);
```

---

## Demo 说明

- Demo 用户名为 `test`，`user_id = 1`，已由 `sql/init.sql` 自动插入。
- 进度保存逻辑：每 10 秒自动上报一次；暂停时立即保存；关闭页面时通过 `sendBeacon` 抢发一次；播放结束自动重置进度为 0。

---

## 备注

- 本项目以"最简可运行"为目标，未实现登录/注册，`user_id` 固定为 `1`。
- 如需多用户支持，只需在接口层添加身份验证（JWT / Session），并将 `CURRENT_USER_ID` 替换为实际用户 ID。
- Nginx 配置中 HLS 文件根路径为 `/data/hls/`，可按需修改。
