package com.example.demo.course.entity;

import jakarta.persistence.*;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@Entity
@Table(name = "section_ai_configs")
public class SectionAiConfig {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "section_id", nullable = false, unique = true)
    private Long sectionId;

    @Column(name = "welcome_message", nullable = false)
    private String welcomeMessage = "你好，我是你的AI助教。";

    @Column(name = "system_prompt", nullable = false, columnDefinition = "TEXT")
    private String systemPrompt;

    @Column(name = "model_name", length = 50)
    private String modelName = "deepseek-chat";

    @Column(name = "updated_at")
    private LocalDateTime updatedAt = LocalDateTime.now();
}
