package com.example.demo.course.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;
import java.util.List;

@Data
public class CourseListResponse {
    private long total;
    private List<CourseListItem> list;

    @Data
    public static class CourseListItem {
        private Long id;
        private String title;
        @JsonProperty("cover_image")
        private String coverImage;
        @JsonProperty("teacher_name")
        private String teacherName;
        private String status;
        private String visibility;
        private String permission;
    }
}
