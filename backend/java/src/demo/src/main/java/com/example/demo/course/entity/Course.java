package com.example.demo.course.entity;

import jakarta.persistence.*;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@Entity
@Table(name = "courses")
public class Course {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "teacher_id", nullable = false)
    private Long teacherId;

    @Column(name = "school_id", nullable = false)
    private Long schoolId;

    @Column(nullable = false)
    private String title;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "cover_image")
    private String coverImage;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private CourseStatus status = CourseStatus.PRE_RELEASE;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private CourseVisibility visibility = CourseVisibility.PUBLIC;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private CoursePermission permission = CoursePermission.OPEN;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt = LocalDateTime.now();

    @Column(name = "updated_at")
    private LocalDateTime updatedAt = LocalDateTime.now();

    public enum CourseStatus {
        PRE_RELEASE, IN_PROGRESS, COMPLETED, HIDDEN
    }

    public enum CourseVisibility {
        PUBLIC, RESTRICTED, PRIVATE
    }

    public enum CoursePermission {
        OPEN, APPLY
    }
}
