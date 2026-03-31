package com.example.demo.course.dto;

import com.example.demo.course.entity.CourseSection;
import lombok.Data;

@Data
public class CreateSectionRequest {
    private String title;
    private CourseSection.SectionType type;
    private Integer orderIndex;
}
