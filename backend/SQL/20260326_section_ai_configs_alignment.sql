-- 迁移目的：将 section_ai_configs 表对齐到当前实体定义
-- 目标字段：page_number, prompt, generated_dsl, updated_at（均满足生产严格校验 validate）
-- 兼容旧结构：如果历史上存在 welcome_message/system_prompt，会自动用于数据回填

BEGIN;

-- 1) 增量补列（先允许为空，避免老数据立即失败）
ALTER TABLE section_ai_configs
    ADD COLUMN IF NOT EXISTS page_number INTEGER,
    ADD COLUMN IF NOT EXISTS prompt TEXT,
    ADD COLUMN IF NOT EXISTS generated_dsl TEXT,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP;

-- 2) page_number 回填与约束
UPDATE section_ai_configs
SET page_number = 1
WHERE page_number IS NULL;

ALTER TABLE section_ai_configs
    ALTER COLUMN page_number SET DEFAULT 1,
    ALTER COLUMN page_number SET NOT NULL;

-- 3) prompt 回填
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'section_ai_configs'
          AND column_name = 'system_prompt'
    ) THEN
        EXECUTE '
            UPDATE section_ai_configs
            SET prompt = COALESCE(prompt, NULLIF(system_prompt, ''''), ''你是一个友好且专业的AI助教，帮助学生解答课程相关问题。'')
            WHERE prompt IS NULL
        ';
    ELSIF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'section_ai_configs'
          AND column_name = 'welcome_message'
    ) THEN
        EXECUTE '
            UPDATE section_ai_configs
            SET prompt = COALESCE(prompt, NULLIF(welcome_message, ''''), ''你是一个友好且专业的AI助教，帮助学生解答课程相关问题。'')
            WHERE prompt IS NULL
        ';
    ELSE
        UPDATE section_ai_configs
        SET prompt = COALESCE(prompt, '你是一个友好且专业的AI助教，帮助学生解答课程相关问题。')
        WHERE prompt IS NULL;
    END IF;
END $$;

ALTER TABLE section_ai_configs
    ALTER COLUMN prompt SET NOT NULL;

-- 4) generated_dsl 回填
UPDATE section_ai_configs
SET generated_dsl = '{}'
WHERE generated_dsl IS NULL OR btrim(generated_dsl) = '';

ALTER TABLE section_ai_configs
    ALTER COLUMN generated_dsl SET NOT NULL;

-- 5) updated_at 回填与默认值
UPDATE section_ai_configs
SET updated_at = CURRENT_TIMESTAMP
WHERE updated_at IS NULL;

ALTER TABLE section_ai_configs
    ALTER COLUMN updated_at SET DEFAULT CURRENT_TIMESTAMP,
    ALTER COLUMN updated_at SET NOT NULL;

-- 6) 索引（与 init.sql 对齐）
CREATE INDEX IF NOT EXISTS idx_section_ai_configs_section_id
    ON section_ai_configs(section_id);

CREATE INDEX IF NOT EXISTS idx_section_ai_configs_page_number
    ON section_ai_configs(page_number);

COMMIT;

