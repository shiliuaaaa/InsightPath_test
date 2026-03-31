package com.example.demo.course.dto;

public class EnrollCourseResponse {

    private String status;
    private String message;

    public EnrollCourseResponse() {
    }

    public EnrollCourseResponse(String status, String message) {
        this.status = status;
        this.message = message;
    }

    // Getters and Setters
    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }
}

