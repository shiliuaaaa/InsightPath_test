package com.example.demo.course.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;

@Data
public class CourseDetailResponse {
    private Long id;
    private String title;
    private String intro;
    @JsonProperty("cover_image")
    private String coverImage;
    private String status;
    private String visibility;
    private String permission;
    @JsonProperty("teacher_name")
    private String teacherName;
    @JsonProperty("is_joined")
    private Boolean joined;
    private CourseStats stats;

    @Data
    public static class CourseStats {
        @JsonProperty("student_count")
        private long studentCount;
        @JsonProperty("resource_count")
        private long resourceCount;
    }
}
