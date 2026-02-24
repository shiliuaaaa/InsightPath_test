# 此分支主要针对Python的AI开发

## 数据库处理


针对数据库出现错误后，如何调试与修改数据库。

**重要易错点：**
- `init.sql` 只会在第一次创建数据库时执行，如果数据库已经存在，修改 `init.sql` 不会有任何效果。

### CLI交互
如果已经执行了`./dev.sh all`, 可以通过以下命令进入数据库容器并使用psql命令行工具进行调试：

```bash
cd /path/InsightPath/backend
docker compose exec db psql -U myuser -d mydatabase
```

进入psql后，可以使用以下命令查看表结构和数据：

```sql
\dt
SELECT * FROM test_connection;
\q -- 退出CLI交互
```

### 生产环境直接重置数据库

项目里有 `init.sql`，并且 `docker-compose.yml` 挂载到了 `/docker-entrypoint-initdb.d`。

如果需要在生产环境直接重置数据库，可以使用以下命令：
```SQL
docker compose down -v
```
这样会，删除旧卷 db_data。

### 部分问题

1. 数据库中的数据存储在哪里？
在这个 `docker-compose.yml` 里，`PostgreSQL` 的实际数据文件存放在 `Docker` 的命名卷 `db_data` 里，对应容器内路径：
`/var/lib/postgresql/data`
也就是这行：
`db_data:/var/lib/postgresql/data`
而这个命名卷 `db_data` 是由 `Docker` 管理的，具体存储位置取决于你的操作系统和 `Docker` 的配置。通常情况下，`Docker` 会在其默认的存储位置创建一个目录来存放命名卷的数据。
在Linux系统上，默认的存储位置通常是：
`/var/lib/docker/volumes/db_data/_data`

2. `./SQL:/docker-entrypoint-initdb.d` 是什么?

 `/docker-entrypoint-initdb.d`：`Postgres` 官方镜像约定的初始化脚本目录