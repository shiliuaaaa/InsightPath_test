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

    @Column(name = "section_id", nullable = false)
    private Long sectionId;

    @Column(name = "page_number", nullable = false)
    private Integer pageNumber;

    @Column(name = "prompt", nullable = false, columnDefinition = "TEXT")
    private String prompt;

    @Column(name = "generated_dsl", nullable = false, columnDefinition = "TEXT")
    private String generatedDsl;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt = LocalDateTime.now();
}
