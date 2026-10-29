# 个人 GitHub / Zeabur 部署

本副本部署到个人仓库 `DDD-DD-9527/nova-image-studio`，分支 `main`，保留原项目 AGPL-3.0 许可证及原有说明。

## 3.4.0 升级（2026-10-30）

- 原源码为 3.1.3；本地运行的 `tianjiangqiji/nova-image-studio:latest` 镜像为 3.4.0，两者来源不同。
- 本仓库现采用上游 `tianjiangqiji/nova-image-studio` 的固定提交 `b8cd44cc083a0429f8df6a7c9fc5b935b7ae0731`（3.4.0），包括视频/插件、Agent、浏览器工具和桌面端源码。该提交与本地镜像后端文件校验和不同，不声称是该镜像的逐字节源码。
- 保留个人 Dockerfile、Compose、`/data` 持久化及 `npm ci --include=dev` 构建修复。未导入上游桌面发布 workflow；不会替个人仓库创建桌面安装包发布。
- 已有 Zeabur 环境变量继续适用，持久化存储继续挂载 `/data`。Dockerfile 新增默认 `NOVA_PLUGIN_MEDIA_DIR=/data/plugin-media`，防止视频插件的参考素材落到临时容器文件系统；也可在 Zeabur 显式设置此变量。
- 使用包含参考素材的视频插件时，建议另设 `NOVA_PUBLIC_BASE_URL=https://你的Zeabur域名`，供上游服务访问素材。模型和 API Key 仍在网页设置中配置。
- CDP 浏览器自动化是本地/桌面能力，云容器默认不安装 Chrome，保持 `NOVA_CDP_ENABLED=false`。云端支持通用网页及模型功能，不承诺连接到用户电脑上的浏览器。
- 插件素材、任务和图片都有上游应用定义的清理期限，持久化挂载不代表永久归档。升级前建议在 Zeabur 对 `/data` 做快照；本轮未操作云端存储或本地运行容器。
- 版本标识来自根目录 `package.json`，前后端 package 均为 3.4.0。部署完成后如仍显示旧界面，关闭旧标签页重新打开；必要时清理该站点缓存（清理前先备份浏览器内保存的模型配置和素材）。

本轮验证：生产构建通过，前端 68 个文件共 672 项测试通过；Linux 隔离容器中的后端 115 项测试通过，三项生产依赖版本与锁文件一致；视频插件 7 组 fixtures 通过。临时容器 `http://127.0.0.1:5283` 首页、队列、插件、提示词、黑名单及 WebSocket 验证通过，未调用付费模型，也未使用现有数据库。

Windows 本机安装 `better-sqlite3@13.0.3` 需要 Visual Studio C++ 工具链，本机缺失，故后端原生模块验证在 Linux 隔离容器执行。Dockerfile 已包含 Linux 编译工具链。Docker 从零构建仍受本机失效 Docker 代理影响；Zeabur 本次升级的实际构建和在线验收尚待部署确认。

## Zeabur 配置

1. 新建项目，从 GitHub 导入上述个人仓库，选择 `main` 分支，构建根目录 `/`。
2. 使用根目录 `Dockerfile` 构建，不覆盖启动命令。Node.js 24 与当前依赖要求兼容（Undici 8 要求 Node >=22.19）。
3. 设置以下环境变量（也可参考 `deploy/zeabur.env.example`）：

   ```env
   NODE_ENV=production
   HOSTNAME=0.0.0.0
   PORT=3000
   NOVA_TASK_DB=/data/nova-tasks.sqlite
   NOVA_IMAGE_DIR=/data/nova-images
   TZ=Asia/Shanghai
   PROMPT_GALLERY_MODE=1
   ```

   Dockerfile 已包含服务器和数据路径默认值；建议在 Zeabur 中显式核对。`HOSTNAME` 需为 `0.0.0.0`，不能使用平台容器的机器名。

4. **首次启动前**添加持久化存储，挂载路径 `/data`。保持 **单实例**，不要多副本共用 SQLite。
5. 设置 HTTP 对外服务端口 `3000`（或平台注入的 `PORT` 对应值），生成 Zeabur 域名。健康检查路径为 `/api/nova/queue-status`。
6. 打开网页，在模型设置中配置模型、API Base URL 和 API Key。该项目没有 JWT 登录，不需要设置 `JWT_SECRET`；API Key 由用户在网页填写，不打包进镜像。
7. 验证首页、提示词广场、模型设置、WebSocket 和生成任务。实际生图会调用你配置的 API 并产生其对应费用，本次部署配置校验不调用付费接口。

前端由同一个 Node 服务托管，API 和 WebSocket 同源，不需要另设前端地址、CORS 或反向代理。

## 可选变量

| 变量 | 用途 |
|---|---|
| `NOVA_API_BASE_URL` | 未在请求中指定时的上游默认地址，默认 `https://api.openai.com` |
| `NOVA_TASK_CONCURRENCY` | 最大并发，原默认值 50；按 API 额度和实例资源调整 |
| `NOVA_TASK_TTL_HOURS` | 任务到期清理时间，默认 12 小时；挂载数据卷不会阻止应用主动清理 |
| `NOVA_IMAGE_STREAM` | 流式图片响应，默认开启，可设置 `false` |
| `PROMPT_GALLERY_MODE` | `1` 常驻、`2` 私密、`3` 关闭 |
| `PROMPT_GALLERY_PASSWORD` | 选择私密模式时设置自己的密码，仅保护提示词广场，不是整站登录 |

队列和限流变量的完整说明见 `backend/.env.example`。Zeabur 环境变量更新后重新部署/重启服务生效。

## 本地 Docker Compose

已有 `.env` 与 `data` 保留；首次全新克隆执行：

```powershell
Copy-Item backend/.env.docker.example .env
# 可在 .env 中添加 HOST_PORT=5283，改用其他空闲端口。
# 启动前检查端口；5173 保留给小黑板。
docker compose up -d --build
docker compose ps
docker compose logs -f
```

默认访问 <http://localhost:5283>。本地 `./data` 挂载到容器 `/data`，不再将本机 `.env` 文件挂载进容器，改由 `env_file` 注入。数据库和图片沿用现有本地 `data` 目录。提示词与黑名单使用 `backend/prompts.json` 和 `backend/blacklist.json`，需要自定义时修改这两个源码文件后重建镜像；根目录同名文件不会自动覆盖它们。

停止并保留数据：`docker compose down`。本地数据不会自动上传到 Zeabur，如需迁移，应停止旧服务后迁移整个数据目录，再挂载到新服务。

## 数据边界

GitHub 仅提交源码、原许可证、文档和部署配置。本机 `.env`、图片、SQLite、日志、依赖目录和构建产物不上传。模型配置等保存在访问者浏览器中，服务重部署不会把本机浏览器配置同步到其他设备。

持久化目录用于任务及图片，仍需按需备份；SQLite 使用 WAL 时应停服务复制整个目录，或使用 SQLite backup API。

## 本次验证（2026-10-29）

Zeabur 会把服务环境变量注入 Docker 构建步骤，因此前端安装命令必须显式带 `--include=dev`。否则 `NODE_ENV=production` 会跳过 TypeScript 等构建依赖，Next.js 无法读取 `tsconfig.json` 的 `@/*` 路径别名，出现 `Can't resolve '@/components/…'`。运行阶段仍使用生产模式，后端依赖仍仅安装生产依赖。

- `npm run build` 通过，Next.js 静态导出成功。
- 前端现有测试 13 个文件、80 项全部通过；后端图片流式回退集成测试 1 项通过，使用本地模拟上游，未调用付费 API。
- `docker compose config --quiet`、后端 JavaScript 语法检查通过。
- 在临时目录以生产模式启动：网页首页、队列状态、提示词、黑名单接口返回 200，WebSocket 握手成功；重启后临时 SQLite 验证数据保留。本地测试 URL 为 `http://127.0.0.1:5283`，验证后已关闭，未使用现有业务数据。
- Docker 镜像构建在拉取 Node 基础镜像阶段被本机失效代理 `127.0.0.1:10809` 阻断。尚未完成容器实际构建、容器卷持久化和 Zeabur 在线运行验证；首次部署需在网络可用的环境完成这些验收。
