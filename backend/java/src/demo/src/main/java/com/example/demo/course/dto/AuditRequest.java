package com.example.demo.course.dto;

import lombok.Data;

@Data
public class AuditRequest {
    private String action; // APPROVE or REJECT
}
