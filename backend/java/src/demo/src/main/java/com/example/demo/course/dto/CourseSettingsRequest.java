package com.example.demo.course.dto;

import com.example.demo.course.entity.Course;
import lombok.Data;

@Data
public class CourseSettingsRequest {
    private String title;
    private String description;
    private Course.CourseStatus status;
    private Course.CourseVisibility visibility;
    private Course.CoursePermission permission;
}
