package com.example.demo.course.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;

@Data
public class CreateCourseRequest {
    private String title;
    private String description;
    @JsonProperty("cover_image")
    private String coverImage;
    @JsonProperty("school_id")
    private Long schoolId;
}
