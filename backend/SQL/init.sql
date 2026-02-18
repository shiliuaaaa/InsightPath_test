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
    username VARCHAR(100) NOT NULL UNIQUE,
    phone VARCHAR(20) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    nickname VARCHAR(100) NOT NULL,
    avatar_url VARCHAR(255),
    role VARCHAR(20) NOT NULL CHECK (role IN ('STUDENT', 'TEACHER')),
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

-- 9. AI配置表 (SectionAIConfigs) - 1:1 扩展 (type=AI)
CREATE TABLE IF NOT EXISTS section_ai_configs (
    id BIGSERIAL PRIMARY KEY,
    section_id BIGINT NOT NULL UNIQUE REFERENCES course_sections(id) ON DELETE CASCADE,
    welcome_message VARCHAR(255) NOT NULL DEFAULT '你好，我是你的AI助教。',
    system_prompt TEXT NOT NULL, -- 隐藏的 Prompt
    model_name VARCHAR(50) DEFAULT 'gpt-4o',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- 10. AI对话记录表 (AIChatMessages) - 1:N 记录 (type=AI)
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
), section AS (
    INSERT INTO course_sections (course_id, title, type, order_index)
    SELECT c.id, 'AI 助教', 'AI', 0
    FROM course c
    RETURNING id
)
INSERT INTO section_ai_configs (section_id, welcome_message, system_prompt, model_name)
SELECT id, '欢迎来到课程AI助教！', '你是一个友好且知识渊博的AI助教，帮助学生解答课程相关问题。', 'deepseek-chat'
FROM section;

INSERT INTO test_connection (info) VALUES ('Database connected successfully!');

