package com.example.demo.course.controller;

import com.example.demo.auth.entity.Role;
import com.example.demo.auth.entity.User;
import com.example.demo.auth.filter.JwtAuthFilter;
import com.example.demo.auth.repository.UserRepository;
import com.example.demo.course.dto.RagSearchRequest; 
import com.example.demo.course.dto.RagSearchResponse; 
import com.example.demo.course.entity.Course;
import com.example.demo.course.entity.CourseFile;
import com.example.demo.course.repository.CourseFileRepository;
import com.example.demo.course.repository.CourseRepository;
import com.example.demo.course.repository.CourseSectionRepository;
import com.example.demo.course.service.RagService;
import com.example.demo.dto.ApiResponse;
import io.jsonwebtoken.Claims;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/rag")
public class RagController {

    @Autowired
    private RagService ragService;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private CourseFileRepository courseFileRepository;

    @Autowired
    private CourseSectionRepository courseSectionRepository; // 需要注入

    @Autowired
    private CourseRepository courseRepository; // 需要注入


    // POST /api/v1/rag/search
    @PostMapping("/search")
    public ResponseEntity<ApiResponse<RagSearchResponse>> semanticSearch(
            @RequestBody RagSearchRequest request, // 使用专门的请求DTO
            HttpServletRequest httpRequest) {

        // 1. 从请求中获取JWT Claims
        Claims claims = (Claims) httpRequest.getAttribute(JwtAuthFilter.CLAIMS_ATTRIBUTE);
        if (claims == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error(HttpStatus.UNAUTHORIZED.value(), "Unauthorized: No valid JWT token found"));
        }

        Long userId = Long.parseLong(claims.get("user_id").toString());
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User not found"));

        // 2. 验证权限
        if (user.getRole() != Role.STUDENT && user.getRole() != Role.TEACHER) {
             return ResponseEntity.status(HttpStatus.FORBIDDEN)
                     .body(ApiResponse.error(HttpStatus.FORBIDDEN.value(), "Access denied"));
        }

        // 4. 执行搜索
        try {
            RagSearchResponse searchResult = ragService.performSemanticSearch(request.getQuery(), request.getDocumentId(), request.getTopK());
            return ResponseEntity.ok(ApiResponse.success("Search successful", searchResult));
        } catch (Exception e) {
            e.printStackTrace(); // 记录错误堆栈
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.error(HttpStatus.INTERNAL_SERVER_ERROR.value(), "An error occurred during search: " + e.getMessage()));
        }
    }

    @PostMapping("/documents/{documentId}/process")
    public ResponseEntity<ApiResponse<Void>> processDocument(
            @PathVariable Long documentId,
            HttpServletRequest httpRequest) {

        // 1. 获取当前用户信息
        Claims claims = (Claims) httpRequest.getAttribute(JwtAuthFilter.CLAIMS_ATTRIBUTE);
        if (claims == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error(HttpStatus.UNAUTHORIZED.value(), "Unauthorized: No valid JWT token found"));
        }
        Long userId = Long.parseLong(claims.get("user_id").toString());
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User not found"));

        // 2. 验证权限
        if (user.getRole() != Role.TEACHER) {
             return ResponseEntity.status(HttpStatus.FORBIDDEN)
                     .body(ApiResponse.error(HttpStatus.FORBIDDEN.value(), "Access denied: Only teachers can process documents"));
        }

        // 3. 验证文档权限：检查文档是否属于该教师创建的课程
        CourseFile file = courseFileRepository.findById(documentId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Document not found"));

        boolean fileBelongsToTeacher = courseFileRepository.existsByIdAndSectionCourseTeacherId(documentId, userId);
        if (!fileBelongsToTeacher) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(ApiResponse.error(HttpStatus.FORBIDDEN.value(), "Access denied: You do not own the course containing this document"));
}       

        // 4. 触发文档处理
        try {
            boolean success = ragService.triggerDocumentProcessing(documentId);
            if (success) {
                 return ResponseEntity.status(HttpStatus.ACCEPTED)
                         .body(ApiResponse.success("Document processing started successfully", null));
            } else {
                 return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                         .body(ApiResponse.error(HttpStatus.INTERNAL_SERVER_ERROR.value(), "Failed to start document processing"));
            }
        } catch (Exception e) {
            e.printStackTrace(); // 记录错误堆栈
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.error(HttpStatus.INTERNAL_SERVER_ERROR.value(), "An error occurred while starting processing: " + e.getMessage()));
        }
    }
}