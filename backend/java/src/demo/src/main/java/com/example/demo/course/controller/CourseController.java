package com.example.demo.course.controller;

import com.example.demo.auth.entity.User;
import com.example.demo.auth.filter.JwtAuthFilter;
import com.example.demo.auth.repository.UserRepository;
import com.example.demo.course.dto.*;
import com.example.demo.course.entity.Course;
import com.example.demo.course.entity.CourseFile;
import com.example.demo.course.entity.CourseSection;
import com.example.demo.course.service.AiChatService;
import com.example.demo.course.service.CourseService;
import com.example.demo.course.service.CourseSyllabusService;
import com.example.demo.course.service.SectionService;
import com.example.demo.dto.ApiResponse;
import io.jsonwebtoken.Claims;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/courses")
public class CourseController {

    private final CourseService courseService;
    private final SectionService sectionService;
    private final AiChatService aiChatService;
    private final CourseSyllabusService courseSyllabusService;
    private final UserRepository userRepository;

    public CourseController(CourseService courseService,
                            SectionService sectionService,
                            AiChatService aiChatService,
                            CourseSyllabusService courseSyllabusService,
                            UserRepository userRepository) {
        this.courseService = courseService;
        this.sectionService = sectionService;
        this.aiChatService = aiChatService;
        this.courseSyllabusService = courseSyllabusService;
        this.userRepository = userRepository;
    }

    // ==================== 课程 CRUD ====================

    /** 获取课程列表 (分页+搜索) */
    @GetMapping
    public ApiResponse<CourseListResponse> listCourses(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(required = false) String keyword,
            @RequestParam(name = "school_id", required = false) Long schoolId,
            HttpServletRequest request) {
        User user = null;
        try {
            user = getCurrentUser(request);
        } catch (ResponseStatusException e) {
            // 忽略未认证异常，允许匿名访问
        }
        CourseListResponse response = courseService.getVisibleCoursesPaged(user, page, keyword, schoolId);
        return ApiResponse.success("获取成功", response);
    }

    /** 创建课程 (教师端) */
    @PostMapping
    public ResponseEntity<ApiResponse<Map<String, Object>>> createCourse(@RequestBody CreateCourseRequest body,
                                                          HttpServletRequest request) {
        User user = getCurrentUser(request);
        Course created = courseService.createCourse(body, user);
        Map<String, Object> data = Map.of(
                "id", created.getId(),
                "title", created.getTitle(),
                "status", created.getStatus().name()
        );
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(new ApiResponse<>(201, "创建成功", data));
    }

    /** 获取课程详情 (实时状态校验) */
    @GetMapping("/{courseId}")
    public ApiResponse<CourseDetailResponse> getCourseDetail(@PathVariable Long courseId,
                                                              HttpServletRequest request) {
        User user = getCurrentUser(request);
        CourseDetailResponse detail = courseService.getCourseDetail(courseId, user);
        return ApiResponse.success("获取成功", detail);
    }

    /** 更新课程设置 (生命周期管理) */
    @PutMapping("/{courseId}/settings")
    public ApiResponse<Void> updateCourseSettings(@PathVariable Long courseId,
                                                   @RequestBody CourseSettingsRequest body,
                                                   HttpServletRequest request) {
        User user = getCurrentUser(request);
        courseService.updateCourseSettings(courseId, body, user);
        return ApiResponse.success("设置更新成功", null);
    }

    /** 删除课程 (教师端) */
    @DeleteMapping("/{courseId}")
    public ApiResponse<Void> deleteCourse(@PathVariable Long courseId,
                                          HttpServletRequest request) {
        User user = getCurrentUser(request);
        courseService.deleteCourse(courseId, user);
        return ApiResponse.success("删除成功", null);
    }

    /** 加入/申请课程 */
    @PostMapping("/{courseId}/enroll")
    public ApiResponse<Map<String, Object>> enrollCourse(@PathVariable Long courseId,
                                                          @RequestBody(required = false) EnrollRequest body,
                                                          HttpServletRequest request) {
        User user = getCurrentUser(request);
        String reason = body != null ? body.getApplyReason() : null;
        Map<String, Object> result = courseService.enrollCourse(courseId, user, reason);
        String status = (String) result.get("status");
        String message = "JOINED".equals(status) ? "加入成功" : "申请已提交，请等待教师审核";
        return ApiResponse.success(message, result);
    }

    // ==================== 栏目管理 ====================

    /** 获取课程栏目列表 */
    @GetMapping("/{courseId}/sections")
    public ApiResponse<List<SectionResponse>> getSections(@PathVariable Long courseId,
                                                           HttpServletRequest request) {
        User user = getCurrentUser(request);
        // 教师（课程创建者）看全部栏目；学生只看未隐藏的
        Course course = courseService.getCourseEntity(courseId);
        List<SectionResponse> sections;
        if (course.getTeacherId().equals(user.getId())) {
            sections = sectionService.getAllSections(courseId);
        } else {
            sections = sectionService.getSections(courseId);
        }
        return ApiResponse.success("获取成功", sections);
    }

    /** 创建栏目 (教师端) */
    @PostMapping("/{courseId}/sections")
    public ResponseEntity<ApiResponse<SectionResponse>> createSection(@PathVariable Long courseId,
                                                       @RequestBody CreateSectionRequest body,
                                                       HttpServletRequest request) {
        User user = getCurrentUser(request);
        SectionResponse section = sectionService.createSection(courseId, body, user);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(new ApiResponse<>(201, "创建成功", section));
    }

    /** 删除栏目 (教师端) */
    @DeleteMapping("/{courseId}/sections/{sectionId}")
    public ApiResponse<Void> deleteSection(@PathVariable Long courseId,
                                            @PathVariable Long sectionId,
                                            HttpServletRequest request) {
        User user = getCurrentUser(request);
        sectionService.deleteSection(courseId, sectionId, user);
        return ApiResponse.success("删除成功", null);
    }

    // ==================== 显示页面 (DISPLAY) ====================

    /** 获取显示页面内容 */
    @GetMapping("/{courseId}/sections/{sectionId}/content")
    public ApiResponse<Map<String, Object>> getDisplayContent(@PathVariable Long courseId,
                                                               @PathVariable Long sectionId) {
        Map<String, Object> content = sectionService.getDisplayContent(sectionId);
        return ApiResponse.success("获取成功", content);
    }

    /** 更新显示页面内容 (教师端) */
    @PutMapping("/{courseId}/sections/{sectionId}/content")
    public ApiResponse<Map<String, Object>> updateDisplayContent(@PathVariable Long courseId,
                                                                  @PathVariable Long sectionId,
                                                                  @RequestBody UpdateContentRequest body,
                                                                  HttpServletRequest request) {
        User user = getCurrentUser(request);
        Map<String, Object> result = sectionService.updateDisplayContent(courseId, sectionId, body.getContent(), user);
        return ApiResponse.success("保存成功", result);
    }

    // ==================== 存储页面 (STORAGE) - 文件管理 ====================

    /** 获取存储页面文件列表 */
    @GetMapping("/{courseId}/sections/{sectionId}/files")
    public ApiResponse<Map<String, Object>> getFiles(@PathVariable Long courseId,
                                                      @PathVariable Long sectionId,
                                                      @RequestParam(name = "parent_id", required = false) Long parentId) {
        Map<String, Object> result = sectionService.getFiles(sectionId, parentId);
        return ApiResponse.success("获取成功", result);
    }

    /** 创建文件夹 */
    @PostMapping("/{courseId}/sections/{sectionId}/folders")
    public ResponseEntity<ApiResponse<CourseFile>> createFolder(@PathVariable Long courseId,
                                                 @PathVariable Long sectionId,
                                                 @RequestParam(name = "parent_id", required = false) Long parentId,
                                                 @RequestParam String name) {
        CourseFile folder = sectionService.createFolder(sectionId, parentId, name);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(new ApiResponse<>(201, "创建成功", folder));
    }

    /** 删除文件或文件夹 */
    @DeleteMapping("/{courseId}/sections/{sectionId}/items/{itemId}")
    public ApiResponse<Void> deleteItem(@PathVariable Long courseId,
                                         @PathVariable Long sectionId,
                                         @PathVariable Long itemId) {
        sectionService.deleteFileOrFolder(itemId);
        return ApiResponse.success("删除成功", null);
    }

    /** 重命名文件或文件夹 */
    @PutMapping("/{courseId}/sections/{sectionId}/items/{itemId}/rename")
    public ApiResponse<Void> renameItem(@PathVariable Long courseId,
                                         @PathVariable Long sectionId,
                                         @PathVariable Long itemId,
                                         @RequestBody RenameItemRequest body) {
        sectionService.renameItem(itemId, body.getName());
        return ApiResponse.success("重命名成功", null);
    }

    // ==================== 课程大纲（可编辑） ====================

    /** 获取课程大纲树 */
    @GetMapping("/{courseId}/syllabus")
    public ApiResponse<List<SyllabusNodeResponse>> getSyllabus(@PathVariable Long courseId,
                                                               HttpServletRequest request) {
        getCurrentUser(request);
        List<SyllabusNodeResponse> data = courseSyllabusService.getSyllabusTree(courseId);
        return ApiResponse.success("获取成功", data);
    }

    /** 创建章节 */
    @PostMapping("/{courseId}/syllabus/chapters")
    public ResponseEntity<ApiResponse<SyllabusNodeResponse>> createChapter(@PathVariable Long courseId,
                                                           @RequestBody CreateSyllabusChapterRequest body,
                                                           HttpServletRequest request) {
        User user = getCurrentUser(request);
        SyllabusNodeResponse created = courseSyllabusService.createChapter(courseId, body, user);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(new ApiResponse<>(201, "创建成功", created));
    }

    /** 在章节下创建知识点 */
    @PostMapping("/{courseId}/syllabus/chapters/{chapterId}/knowledge")
    public ResponseEntity<ApiResponse<SyllabusNodeResponse>> createKnowledge(@PathVariable Long courseId,
                                                             @PathVariable Long chapterId,
                                                             @RequestBody CreateSyllabusKnowledgeRequest body,
                                                             HttpServletRequest request) {
        User user = getCurrentUser(request);
        SyllabusNodeResponse created = courseSyllabusService.createKnowledge(courseId, chapterId, body, user);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(new ApiResponse<>(201, "创建成功", created));
    }

    /** 在章节下创建习题 */
    @PostMapping("/{courseId}/syllabus/chapters/{chapterId}/quiz")
    public ResponseEntity<ApiResponse<SyllabusNodeResponse>> createQuiz(@PathVariable Long courseId,
                                                        @PathVariable Long chapterId,
                                                        @RequestBody CreateSyllabusQuizRequest body,
                                                        HttpServletRequest request) {
        User user = getCurrentUser(request);
        SyllabusNodeResponse created = courseSyllabusService.createQuiz(courseId, chapterId, body, user);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(new ApiResponse<>(201, "创建成功", created));
    }

    // ==================== 学生管理 ====================

    /** 获取课程成员列表 */
    @GetMapping("/{courseId}/students")
    public ApiResponse<Map<String, Object>> getStudents(@PathVariable Long courseId,
                                                         @RequestParam(defaultValue = "1") int page,
                                                         @RequestParam(required = false) String status,
                                                         HttpServletRequest request) {
        User user = getCurrentUser(request);
        Map<String, Object> result = courseService.getStudentList(courseId, status, page, 20, user);
        return ApiResponse.success("获取成功", result);
    }

    /** 审核学生申请 */
    @PostMapping("/{courseId}/applications/{applicationId}/audit")
    public ApiResponse<Void> auditApplication(@PathVariable Long courseId,
                                               @PathVariable Long applicationId,
                                               @RequestBody AuditRequest body,
                                               HttpServletRequest request) {
        User user = getCurrentUser(request);
        courseService.auditApplication(courseId, applicationId, body.getAction(), user);
        return ApiResponse.success("操作成功", null);
    }

    /** 移除学生 */
    @DeleteMapping("/{courseId}/students/{studentId}")
    public ApiResponse<Void> removeStudent(@PathVariable Long courseId,
                                            @PathVariable Long studentId,
                                            HttpServletRequest request) {
        User user = getCurrentUser(request);
        courseService.removeStudent(courseId, studentId, user);
        return ApiResponse.success("移除成功", null);
    }

    /** 搜索学生 (用于邀请) */
    @GetMapping("/{courseId}/students/search")
    public ApiResponse<Map<String, Object>> searchStudents(@PathVariable Long courseId,
                                                            @RequestParam String keyword,
                                                            HttpServletRequest request) {
        User user = getCurrentUser(request);
        Map<String, Object> result = courseService.searchStudents(courseId, keyword, user);
        return ApiResponse.success("搜索成功", result);
    }

    /** 邀请学生加入 */
    @PostMapping("/{courseId}/students/invite")
    public ApiResponse<Void> inviteStudent(@PathVariable Long courseId,
                                            @RequestParam String username,
                                            HttpServletRequest request) {
        User user = getCurrentUser(request);
        courseService.inviteStudent(courseId, username, user);
        return ApiResponse.success("邀请成功", null);
    }

    // ==================== AI 页面 ====================

    /** 获取 AI 页面配置 */
    @GetMapping("/{courseId}/ai/config")
    public ApiResponse<Map<String, Object>> getAiConfig(@PathVariable Long courseId,
                                                         HttpServletRequest request) {
        User user = getCurrentUser(request);
        CourseSection aiSection = requireAiSection(courseId);
        Map<String, Object> config = sectionService.getAiConfig(courseId, aiSection.getId(), user);
        return ApiResponse.success("获取成功", config);
    }

    /** 更新 AI 页面配置 (教师端) */
    @PutMapping("/{courseId}/ai/config")
    public ApiResponse<Void> updateAiConfig(@PathVariable Long courseId,
                                             @RequestBody AiConfigRequest body,
                                             HttpServletRequest request) {
        User user = getCurrentUser(request);
        CourseSection aiSection = requireAiSection(courseId);
        sectionService.updateAiConfig(courseId, aiSection.getId(), body, user);
        return ApiResponse.success("设置已更新", null);
    }

    /** 发送 AI 对话消息 (学生端) */
    @PostMapping("/{courseId}/ai/chat")
    public ApiResponse<Map<String, Object>> aiChat(@PathVariable Long courseId,
                                                    @RequestBody AiChatRequest body,
                                                    HttpServletRequest request) {
        User user = getCurrentUser(request);
        CourseSection aiSection = requireAiSection(courseId);
        Map<String, Object> result = aiChatService.chat(aiSection.getId(), user.getId(), body.getMessage());
        return ApiResponse.success("回复成功", result);
    }

    /** 获取历史对话记录 (学生端) */
    @GetMapping("/{courseId}/ai/history")
    public ApiResponse<Map<String, Object>> getAiHistory(@PathVariable Long courseId,
                                                          @RequestParam(defaultValue = "1") int page,
                                                          @RequestParam(name = "page_size", defaultValue = "20") int pageSize,
                                                          HttpServletRequest request) {
        User user = getCurrentUser(request);
        CourseSection aiSection = requireAiSection(courseId);
        Map<String, Object> result = sectionService.getAiHistory(aiSection.getId(), user.getId(), page, pageSize);
        return ApiResponse.success("获取成功", result);
    }

    /** 清除对话记录 (学生端) */
    @DeleteMapping("/{courseId}/ai/history")
    public ApiResponse<Void> clearAiHistory(@PathVariable Long courseId,
                                             HttpServletRequest request) {
        User user = getCurrentUser(request);
        CourseSection aiSection = requireAiSection(courseId);
        sectionService.deleteAiHistory(aiSection.getId(), user.getId());
        return ApiResponse.success("对话记录已清除", null);
    }

    // ==================== 辅助方法 ====================

    /** 获取指定课程的 AI 栏目，不存在则 404 */
    private CourseSection requireAiSection(Long courseId) {
        CourseSection aiSection = sectionService.findAiSection(courseId);
        if (aiSection == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "该课程没有AI栏目");
        }
        return aiSection;
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
