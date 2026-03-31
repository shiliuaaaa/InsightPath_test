-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- 1. 学校表 (Schools) - 基础字典
CREATE TABLE IF NOT EXISTS schools (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    region_code VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 默认学校（保证 courses.school_id=1 可用）
INSERT INTO schools (id, name, region_code)
VALUES (1, '示例大学', '000000')
ON CONFLICT (id) DO NOTHING;

SELECT setval('schools_id_seq', GREATEST((SELECT COALESCE(MAX(id), 1) FROM schools), 1), true);

-- 2. 用户表 (Users) - 核心用户
CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(32) NOT NULL UNIQUE,
    phone VARCHAR(20) NOT NULL,
    password_hash VARCHAR(100) NOT NULL,
    nickname VARCHAR(32) NOT NULL,
    avatar_url VARCHAR(255),
    bg_url VARCHAR(255),
    bio TEXT,
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
    course_id BIGINT NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
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
    pdf_url VARCHAR(512), -- 预览 PDF 链接（与实体字段对齐）
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE course_files ADD COLUMN IF NOT EXISTS pdf_url VARCHAR(512);

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

ALTER TABLE users ADD COLUMN IF NOT EXISTS bg_url VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS bio TEXT;

-- 9. AI预设锚点表 (SectionAIConfigs) - 1:N 扩展 (type=AI)
CREATE TABLE IF NOT EXISTS section_ai_configs (
    id BIGSERIAL PRIMARY KEY,
    section_id BIGINT NOT NULL REFERENCES course_sections(id) ON DELETE CASCADE,
    page_number INTEGER NOT NULL,
    prompt TEXT NOT NULL,
    generated_dsl TEXT NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_section_ai_configs_section_id ON section_ai_configs(section_id);
CREATE INDEX IF NOT EXISTS idx_section_ai_configs_page_number ON section_ai_configs(page_number);


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

-- 13. 可编辑课程大纲节点表（章节 / 知识点 / 习题）
CREATE TABLE IF NOT EXISTS course_syllabus_nodes (
    id BIGSERIAL PRIMARY KEY,
    course_id BIGINT NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    parent_id BIGINT REFERENCES course_syllabus_nodes(id) ON DELETE CASCADE,
    type VARCHAR(20) NOT NULL CHECK (type IN ('CHAPTER', 'KNOWLEDGE', 'QUIZ_CHOICE', 'QUIZ_ESSAY')),
    title VARCHAR(255) NOT NULL,
    order_index INTEGER NOT NULL DEFAULT 0,
    resource_file_id BIGINT REFERENCES course_files(id) ON DELETE SET NULL,
    question_text TEXT,
    options_json TEXT,
    answer_text TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_course_syllabus_nodes_course_id ON course_syllabus_nodes(course_id);
CREATE INDEX IF NOT EXISTS idx_course_syllabus_nodes_parent_id ON course_syllabus_nodes(parent_id);

-- 兼容已存在数据库：确保 course_members.course_id 支持课程删除级联
ALTER TABLE course_members DROP CONSTRAINT IF EXISTS course_members_course_id_fkey;
ALTER TABLE course_members
    ADD CONSTRAINT course_members_course_id_fkey
    FOREIGN KEY (course_id) REFERENCES courses(id) ON DELETE CASCADE;

-- Create a sample table just to verify connectivity
CREATE TABLE IF NOT EXISTS test_connection (
    id BIGSERIAL PRIMARY KEY,
    info TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 连通性示例数据（可重复执行）
INSERT INTO test_connection (info) VALUES ('Database connected successfully!');

--新增：
-- 扩展现有 course_files 表，添加解析状态字段
ALTER TABLE course_files ADD COLUMN IF NOT EXISTS parsed_status VARCHAR(20) DEFAULT 'NOT_PARSED';
-- 可选值: 'NOT_PARSED', 'PARSING', 'PARSED', 'FAILED'

-- 创建文档文本块表（用于存储OCR结果和向量）
CREATE TABLE IF NOT EXISTS document_text_chunks (
    id BIGSERIAL PRIMARY KEY,
    document_id BIGINT NOT NULL REFERENCES course_files(id) ON DELETE CASCADE, -- 关联course_files表
    page_number INTEGER NOT NULL,
    content TEXT NOT NULL,
    chunk_type VARCHAR(50) DEFAULT 'paragraph', -- 'title', 'paragraph', 'formula', 'list', 'table'
    normalized_coords DOUBLE PRECISION[4], -- [x0, y0, x1, y1] 归一化坐标
    embedding_vector vector(1024), -- 使用pgvector存储向量
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 创建全文检索索引（使用pg_jieba）
CREATE INDEX IF NOT EXISTS idx_document_chunks_content_gin ON document_text_chunks USING GIN(to_tsvector('jiebacfg', content));
-- 创建向量相似度索引
CREATE INDEX IF NOT EXISTS idx_document_chunks_embedding ON document_text_chunks USING ivfflat (embedding_vector vector_cosine_ops) WITH (lists = 100);

-- 创建复合索引优化查询
CREATE INDEX IF NOT EXISTS idx_document_chunks_doc_page ON document_text_chunks(document_id, page_number);