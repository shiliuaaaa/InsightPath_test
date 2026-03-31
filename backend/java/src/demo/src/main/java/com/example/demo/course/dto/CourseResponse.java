package com.example.demo.course.dto;

import com.example.demo.course.entity.CoursePermission;
import com.example.demo.course.entity.CourseStatus;
import com.example.demo.course.entity.CourseVisibility;

import java.time.LocalDateTime;

public class CourseResponse {

    private Long id;
    private String title;
    private String description;
    private String coverImage;
    private Long teacherId;
    private String teacherName;
    private Long schoolId;
    private CourseStatus status;
    private CourseVisibility visibility;
    private CoursePermission permission;
    private Boolean isJoined;
    private Integer studentCount;
    private LocalDateTime createdAt;

    // Getters and Setters
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public String getCoverImage() {
        return coverImage;
    }

    public void setCoverImage(String coverImage) {
        this.coverImage = coverImage;
    }

    public Long getTeacherId() {
        return teacherId;
    }

    public void setTeacherId(Long teacherId) {
        this.teacherId = teacherId;
    }

    public String getTeacherName() {
        return teacherName;
    }

    public void setTeacherName(String teacherName) {
        this.teacherName = teacherName;
    }

    public Long getSchoolId() {
        return schoolId;
    }

    public void setSchoolId(Long schoolId) {
        this.schoolId = schoolId;
    }

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

    public Boolean getIsJoined() {
        return isJoined;
    }

    public void setIsJoined(Boolean isJoined) {
        this.isJoined = isJoined;
    }

    public Integer getStudentCount() {
        return studentCount;
    }

    public void setStudentCount(Integer studentCount) {
        this.studentCount = studentCount;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }
}

