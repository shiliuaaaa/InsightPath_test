package com.example.demo.course.dto;

import com.example.demo.course.entity.CoursePermission;
import com.example.demo.course.entity.CourseStatus;
import com.example.demo.course.entity.CourseVisibility;

public class UpdateCourseSettingsRequest {

    private CourseStatus status;
    private CourseVisibility visibility;
    private CoursePermission permission;

    // Getters and Setters
    public CourseStatus getStatus() {
        return status;
    }

    public void setStatus(CourseStatus status) {
        this.status = status;
    }

    public CourseVisibility getVisibility() {
        return visibility;
    }

    public void setVisibility(CourseVisibility visibility) {
        this.visibility = visibility;
    }

    public CoursePermission getPermission() {
        return permission;
    }

    public void setPermission(CoursePermission permission) {
        this.permission = permission;
    }
}

