package com.example.demo.course.controller;

import com.example.demo.auth.entity.Role;
import com.example.demo.auth.entity.User;
import com.example.demo.auth.filter.JwtAuthFilter;
import com.example.demo.auth.repository.UserRepository;
import com.example.demo.course.dto.SaveSectionAiConfigRequest;
import com.example.demo.course.dto.SectionAiConfigItemResponse;
import com.example.demo.course.entity.Course;
import com.example.demo.course.entity.CourseSection;
import com.example.demo.course.entity.SectionAiConfig;
import com.example.demo.course.repository.CourseRepository;
import com.example.demo.course.repository.CourseSectionRepository;
import com.example.demo.course.repository.SectionAiConfigRepository;
import com.example.demo.dto.ApiResponse;
import io.jsonwebtoken.Claims;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;
import java.util.List;

@RestController
@RequestMapping("/api/v1/sections")
public class SectionAiConfigController {

    private final SectionAiConfigRepository sectionAiConfigRepository;
    private final CourseSectionRepository courseSectionRepository;
    private final CourseRepository courseRepository;
    private final UserRepository userRepository;

    public SectionAiConfigController(SectionAiConfigRepository sectionAiConfigRepository,
                                     CourseSectionRepository courseSectionRepository,
                                     CourseRepository courseRepository,
                                     UserRepository userRepository) {
        this.sectionAiConfigRepository = sectionAiConfigRepository;
        this.courseSectionRepository = courseSectionRepository;
        this.courseRepository = courseRepository;
        this.userRepository = userRepository;
    }

    @PostMapping("/{sectionId}/ai-configs")
    public ResponseEntity<ApiResponse<SectionAiConfigItemResponse>> savePreset(@PathVariable Long sectionId,
                                                               @RequestBody SaveSectionAiConfigRequest body,
                                                               HttpServletRequest request) {
        if (body.getPageNumber() == null || body.getPageNumber() <= 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "page_number 必须为正整数");
        }
        if (body.getPrompt() == null || body.getPrompt().isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "prompt 不能为空");
        }
        if (body.getGeneratedDsl() == null || body.getGeneratedDsl().isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "generated_dsl 不能为空");
        }

        User user = getCurrentUser(request);
        ensureTeacherCanOperateSection(user, sectionId);

        sectionAiConfigRepository.deleteBySectionIdAndPageNumber(sectionId, body.getPageNumber());

        SectionAiConfig config = new SectionAiConfig();
        config.setSectionId(sectionId);
        config.setPageNumber(body.getPageNumber());
        config.setPrompt(body.getPrompt());
        config.setGeneratedDsl(body.getGeneratedDsl());
        config.setUpdatedAt(LocalDateTime.now());

        SectionAiConfig saved = sectionAiConfigRepository.save(config);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(new ApiResponse<>(201, "保存成功", toItem(saved)));
    }

    @GetMapping("/{sectionId}/ai-configs")
    public ApiResponse<List<SectionAiConfigItemResponse>> listPresets(@PathVariable Long sectionId,
                                                                       HttpServletRequest request) {
        User user = getCurrentUser(request);
        ensureTeacherOrStudentCanViewSection(user, sectionId);

        List<SectionAiConfigItemResponse> list = sectionAiConfigRepository
                .findBySectionIdOrderByPageNumberAscUpdatedAtDesc(sectionId)
                .stream()
                .map(this::toItem)
                .toList();

        return ApiResponse.success("获取成功", list);
    }

    private SectionAiConfigItemResponse toItem(SectionAiConfig cfg) {
        SectionAiConfigItemResponse item = new SectionAiConfigItemResponse();
        item.setId(cfg.getId());
        item.setSectionId(cfg.getSectionId());
        item.setPageNumber(cfg.getPageNumber());
        item.setPrompt(cfg.getPrompt());
        item.setGeneratedDsl(cfg.getGeneratedDsl());
        item.setUpdatedAt(cfg.getUpdatedAt());
        return item;
    }

    private void ensureTeacherCanOperateSection(User user, Long sectionId) {
        CourseSection section = courseSectionRepository.findById(sectionId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "栏目不存在"));
        Course course = courseRepository.findById(section.getCourseId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "课程不存在"));

        if (user.getRole() != Role.TEACHER || !course.getTeacherId().equals(user.getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "无权保存该栏目预设");
        }
    }

    private void ensureTeacherOrStudentCanViewSection(User user, Long sectionId) {
        CourseSection section = courseSectionRepository.findById(sectionId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "栏目不存在"));
        Course course = courseRepository.findById(section.getCourseId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "课程不存在"));

        if (user.getRole() == Role.TEACHER && course.getTeacherId().equals(user.getId())) {
            return;
        }
        // 学生默认允许查看（与课程可见性逻辑保持一致，避免过度阻断）
    }

    private User getCurrentUser(HttpServletRequest request) {
        Claims claims = (Claims) request.getAttribute(JwtAuthFilter.CLAIMS_ATTRIBUTE);
        if (claims == null) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "未认证");
        }
        Long userId = extractUserId(claims.get("user_id"));
        return userRepository.findById(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "用户不存在"));
    }

    private Long extractUserId(Object rawUserId) {
        if (rawUserId instanceof Number number) {
            return number.longValue();
        }
        if (rawUserId instanceof String text) {
            try {
                return Long.parseLong(text);
            } catch (NumberFormatException ex) {
                throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "无效的用户ID");
            }
        }
        throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "无效的用户ID");
    }
}

