# InsightPath（灵犀知径）项目运行说明

这份文档给**做视频演示的队友**使用：按步骤配置环境并启动项目。

## 1. 项目结构

- `frontend/src/InsightPath`：Flutter 前端
- `backend/java/src/demo`：Spring Boot 后端（默认端口 `8080`）
- `backend/python/src`：FastAPI + AI 服务（默认端口 `5001`）
- `backend/docker-compose.yml`：数据库与后端容器编排
- `backend/SQL/init.sql`：数据库初始化脚本

---

## 2. 环境要求

建议：

- Java 17
- Python 3.10+
- Flutter SDK（执行 `flutter doctor` 检查）
- Docker Desktop（推荐用于启动数据库）
- LibreOffice插件
---

## 3. 先启动数据库（重要）

> `start.sh` 不会帮你自动启动数据库。请先把 DB 起好。

### 3.1 用 Docker 启动数据库（推荐）

在项目根目录执行：

```bash
cd backend
docker compose up -d db
```

查看数据库容器状态：

```bash
docker compose ps
```

查看数据库日志：

```bash
docker compose logs -f db
```

### 3.2 数据库默认配置

`docker-compose.yml` 中默认是：

- Host: `localhost`
- Port: `5432`
- DB: `mydatabase`
- User: `myuser`
- Password: `mypassword`

这些默认值与项目后端默认配置一致，直接可用。

### 3.3 首次初始化说明

- `backend/SQL/init.sql` 会在**首次建库**时自动执行。
- 如果你改了 `init.sql` 想重建数据库：

```bash
cd backend
docker compose down -v
docker compose up -d db
```

---

## 4. 配置环境变量

必须配置：

```bash
export DEEPSEEK_API_KEY=你的key
```

可选：

```bash
export LLM_MODEL=deepseek-reasoner
export DB_HOST=localhost
export DB_NAME=mydatabase
export DB_USER=myuser
export DB_PASS=mypassword
export PYTHON_PORT=5001
```

也可以写入：`backend/python/src/.env`（`start.sh` 会自动读取）。

---

## 5. 启动项目（后端+前端）

回到项目根目录后执行：

```bash
./start.sh
```

它会启动：

1. Java 后端（8080）
2. Python AI（5001）
3. Flutter 前端（默认按脚本在 macOS/Linux 启动桌面端）

如果没有执行权限：

```bash
chmod +x ./start.sh
```

---

## 6. 前端多平台启动说明（macOS / Windows / Web / Android）

进入前端目录：

```bash
cd frontend/src/InsightPath
flutter pub get
```

先查看可用设备：

```bash
flutter devices
```

### 6.1 macOS

```bash
flutter run -d macos
```

### 6.2 Windows

在 Windows 机器上执行：

```bash
flutter config --enable-windows-desktop
flutter run -d windows
```

### 6.3 Web

```bash
flutter config --enable-web
flutter run -d chrome
```

### 6.4 Android

先确保有模拟器或真机（开启 USB 调试），然后：

```bash
flutter run -d android
```

如果有多个 Android 设备，先 `flutter devices` 看 ID，再：

```bash
flutter run -d <device_id>
```

---

## 7. 分模块启动（调试）

项目根目录：

```bash
./start.sh backend   # Java + Python
./start.sh java      # 仅 Java
./start.sh python    # 仅 Python
./start.sh frontend  # 仅前端（脚本内按系统选择）
```

---

## 8. 运行后检查

- Java：`http://localhost:8080`
- Python：`http://localhost:5001`
- Python 健康检查：`http://localhost:5001/health`

日志：

```bash
tail -f /tmp/java_backend.log
tail -f /tmp/python_ai.log
```

---

## 9. 动画演示开关（录视频用）

文件：`frontend/src/InsightPath/lib/pages/animation_player_page.dart`

参数：

- `_useAiGeneratedAnimation = false`：默认本地冒泡排序（更稳）
- `_useAiGeneratedAnimation = true`：调用 AI 生成动画（展示能力）

---

## 10. 常见问题

### 10.1 AI 对话失败

优先检查：

1. `DEEPSEEK_API_KEY` 是否设置
2. `http://localhost:5001/health` 是否返回 `ok`
3. 外网是否能访问 DeepSeek

### 10.2 Java 启动失败

常见原因：

- 数据库没起
- 端口 `8080` 被占用
- 数据库连接参数不一致

### 10.3 Flutter 启动失败

先执行：

```bash
flutter doctor
```

把缺失依赖补齐后再运行。
