package com.example.demo.course.dto;

import com.example.demo.course.entity.Course;
import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;

@Data
public class CourseSettingsRequest {
    private String title;
    private String description;
    @JsonProperty("cover_image")
    private String coverImage;
    private Course.CourseStatus status;
    private Course.CourseVisibility visibility;
    private Course.CoursePermission permission;
}
