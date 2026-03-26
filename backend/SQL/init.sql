-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- 1. 学校表 (Schools) - 基础字典
CREATE TABLE IF NOT EXISTS schools (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    region_code VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. 用户表 (Users) - 核心用户
CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(32) NOT NULL UNIQUE,
    phone VARCHAR(20) NOT NULL,
    password_hash VARCHAR(100) NOT NULL,
    nickname VARCHAR(32) NOT NULL,
    avatar_url VARCHAR(255),
    role VARCHAR(16) NOT NULL CHECK (role IN ('STUDENT', 'TEACHER')),
    school_id BIGINT REFERENCES schools(id), -- 学生选填，教师认证后更新
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (phone, role)
);

-- 3. 教师认证表 (TeacherVerifications) - 可选
CREATE TABLE IF NOT EXISTS teacher_verifications (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL UNIQUE REFERENCES users(id),
    real_name VARCHAR(100) NOT NULL,
    certification_url VARCHAR(255) NOT NULL,
    status VARCHAR(20) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reviewed_at TIMESTAMP
);

-- 4. 课程主表 (Courses) - 核心业务对象
CREATE TABLE IF NOT EXISTS courses (
    id BIGSERIAL PRIMARY KEY,
    teacher_id BIGINT NOT NULL REFERENCES users(id),
    school_id BIGINT NOT NULL REFERENCES schools(id),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    cover_image VARCHAR(255),
    -- 课程状态: 预发布, 进行中, 已完结, 隐藏
    status VARCHAR(20) NOT NULL DEFAULT 'PRE_RELEASE' CHECK (status IN ('PRE_RELEASE', 'IN_PROGRESS', 'COMPLETED', 'HIDDEN')),
    -- 可见性: 公开, 限制(仅本校), 私密
    visibility VARCHAR(20) NOT NULL DEFAULT 'PUBLIC' CHECK (visibility IN ('PUBLIC', 'RESTRICTED', 'PRIVATE')),
    -- 准入权限: 开放, 申请
    permission VARCHAR(20) NOT NULL DEFAULT 'OPEN' CHECK (permission IN ('OPEN', 'APPLY')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5. 课程成员表 (CourseMembers) - 记录成功加入的学生
CREATE TABLE IF NOT EXISTS course_members (
    id BIGSERIAL PRIMARY KEY,
    course_id BIGINT NOT NULL REFERENCES courses(id),
    user_id BIGINT NOT NULL REFERENCES users(id),
    -- status: PENDING(申请中), JOINED(已加入)
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'JOINED')),
    role VARCHAR(20) DEFAULT 'STUDENT',
    apply_reason VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    approved_at TIMESTAMP,
    UNIQUE (course_id, user_id) -- 防止重复申请/加入
);

-- 6. 课程栏目表 (CourseSections) - 课程内容的骨架
CREATE TABLE IF NOT EXISTS course_sections (
    id BIGSERIAL PRIMARY KEY,
    course_id BIGINT NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    title VARCHAR(64) NOT NULL,
    -- type: DISPLAY(富文本), STORAGE(网盘), AI(问答助教)
    type VARCHAR(20) NOT NULL CHECK (type IN ('DISPLAY', 'STORAGE', 'AI')),
    order_index INTEGER NOT NULL DEFAULT 0,
    is_hidden BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 7. 栏目富文本内容表 (SectionContents) - 1:1 扩展 (type=DISPLAY)
CREATE TABLE IF NOT EXISTS section_contents (
    id BIGSERIAL PRIMARY KEY,
    section_id BIGINT NOT NULL UNIQUE REFERENCES course_sections(id) ON DELETE CASCADE,
    content TEXT, -- Markdown内容
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 8. 课程文件表 (CourseFiles) - 1:N 扩展 (type=STORAGE)
CREATE TABLE IF NOT EXISTS course_files (
    id BIGSERIAL PRIMARY KEY,
    section_id BIGINT NOT NULL REFERENCES course_sections(id) ON DELETE CASCADE,
    parent_id BIGINT REFERENCES course_files(id) ON DELETE CASCADE, -- 支持文件夹层级
    type VARCHAR(20) NOT NULL CHECK (type IN ('FILE', 'FOLDER')),
    name VARCHAR(255) NOT NULL,
    file_url VARCHAR(255), -- 仅 FILE 类型有效
    file_size BIGINT,
    file_ext VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 8.1 课程文件索引 (加速目录树查询)
CREATE INDEX IF NOT EXISTS idx_course_files_section_id ON course_files(section_id);
CREATE INDEX IF NOT EXISTS idx_course_files_parent_id ON course_files(parent_id);

-- 8.2 文件元数据表 (FileMetadata) - 统一文件上传/下载入口
-- usage: AVATAR, COURSE_COVER, COURSE_MATERIAL
CREATE TABLE IF NOT EXISTS file_metadata (
    id BIGSERIAL PRIMARY KEY,
    original_name VARCHAR(255) NOT NULL,
    stored_name VARCHAR(255) NOT NULL UNIQUE, -- 存储在磁盘/OSS 的唯一文件名
    usage VARCHAR(32) NOT NULL CHECK (usage IN ('AVATAR', 'COURSE_COVER', 'COURSE_MATERIAL')),
    size BIGINT NOT NULL,
    content_type VARCHAR(100),
    business_id BIGINT, -- 业务主ID: AVATAR->user_id, COURSE_COVER/COURSE_MATERIAL->course_id
    section_id BIGINT REFERENCES course_sections(id) ON DELETE SET NULL,
    storage_path VARCHAR(512) NOT NULL, -- 物理路径/对象存储 Key (禁止对前端暴露)
    pdf_url VARCHAR(512),               -- 转码后的 PDF 预览链接 (Office 文件转码后填入)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_file_metadata_usage ON file_metadata(usage);
CREATE INDEX IF NOT EXISTS idx_file_metadata_business_id ON file_metadata(business_id);
CREATE INDEX IF NOT EXISTS idx_file_metadata_section_id ON file_metadata(section_id);

-- 9. AI配置表 (SectionAIConfigs) - 1:1 扩展 (type=AI)
CREATE TABLE IF NOT EXISTS section_ai_configs (
    id BIGSERIAL PRIMARY KEY,
    section_id BIGINT NOT NULL UNIQUE REFERENCES course_sections(id) ON DELETE CASCADE,
    welcome_message VARCHAR(255) NOT NULL DEFAULT '你好，我是你的AI助教。',
    system_prompt TEXT NOT NULL, -- 隐藏的 Prompt
    model_name VARCHAR(50) DEFAULT 'gpt-4o',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- 10. 全局 AI 会话表 (GlobalChatSessions)
CREATE TABLE IF NOT EXISTS ai_chat_session (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_ai_chat_session_user_id ON ai_chat_session(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_chat_session_updated_at ON ai_chat_session(updated_at DESC);

-- 11. 全局 AI 对话消息表 (GlobalAiChatMessages)
CREATE TABLE IF NOT EXISTS global_ai_chat_message (
    id BIGSERIAL PRIMARY KEY,
    session_id BIGINT NOT NULL REFERENCES ai_chat_session(id) ON DELETE CASCADE,
    role VARCHAR(50) NOT NULL CHECK (role IN ('user', 'assistant')),
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_global_ai_chat_message_session_id ON global_ai_chat_message(session_id);
CREATE INDEX IF NOT EXISTS idx_global_ai_chat_message_created_at ON global_ai_chat_message(created_at);

-- 12. AI对话记录表 (AIChatMessages) - 1:N 记录 (type=AI)
CREATE TABLE IF NOT EXISTS ai_chat_messages (
    id BIGSERIAL PRIMARY KEY,
    section_id BIGINT NOT NULL REFERENCES course_sections(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL CHECK (role IN ('USER', 'ASSISTANT')),
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create a sample table just to verify connectivity
CREATE TABLE IF NOT EXISTS test_connection (
    id BIGSERIAL PRIMARY KEY,
    info TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);



WITH school AS (
    INSERT INTO schools (name)
    VALUES ('示例大学')
    RETURNING id
), teacher AS (
    INSERT INTO users (username, phone, password_hash, nickname, role, school_id)
    SELECT 'teacher1', '13800000000', 'hash', 'Teacher One', 'TEACHER', id
    FROM school
    RETURNING id
), course AS (
    INSERT INTO courses (teacher_id, school_id, title, description, status, visibility, permission)
    SELECT t.id, s.id, '示例课程', '示例课程简介', 'IN_PROGRESS', 'PUBLIC', 'OPEN'
    FROM teacher t, school s
    RETURNING id
), sec_display AS (
    INSERT INTO course_sections (course_id, title, type, order_index)
    SELECT c.id, '讲义', 'DISPLAY', 0 FROM course c
    RETURNING id
), sec_storage AS (
    INSERT INTO course_sections (course_id, title, type, order_index)
    SELECT c.id, '资料', 'STORAGE', 1 FROM course c
    RETURNING id
), sec_ai AS (
    INSERT INTO course_sections (course_id, title, type, order_index)
    SELECT c.id, 'AI 助教', 'AI', 2 FROM course c
    RETURNING id
), init_display AS (
    INSERT INTO section_contents (section_id, content)
    SELECT id, '# 欢迎来到示例课程

请教师在此编辑课程讲义内容。' FROM sec_display
)
INSERT INTO section_ai_configs (section_id, welcome_message, system_prompt, model_name)
SELECT id, '欢迎来到课程AI助教！', '你是一个友好且知识渊博的AI助教，帮助学生解答课程相关问题。', 'deepseek-chat'
FROM sec_ai;

INSERT INTO test_connection (info) VALUES ('Database connected successfully!');

