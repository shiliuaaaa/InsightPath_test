package com.example.demo.course.service;

import com.example.demo.auth.entity.Role;
import com.example.demo.auth.entity.User;
import com.example.demo.auth.repository.UserRepository;
import com.example.demo.common.entity.FileUsage;
import com.example.demo.common.repository.FileMetadataRepository;
import com.example.demo.course.dto.*;
import com.example.demo.course.entity.Course;
import com.example.demo.course.entity.CourseMember;
import com.example.demo.course.entity.CourseSection;
import com.example.demo.course.entity.SectionAiConfig;
import com.example.demo.course.entity.SectionContent;
import com.example.demo.course.repository.CourseFileRepository;
import com.example.demo.course.repository.CourseMemberRepository;
import com.example.demo.course.repository.CourseRepository;
import com.example.demo.course.repository.CourseSectionRepository;
import com.example.demo.course.repository.SectionAiConfigRepository;
import com.example.demo.course.repository.SectionContentRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;
import java.util.*;

@Service
public class CourseService {

    private final CourseRepository courseRepository;
    private final CourseMemberRepository courseMemberRepository;
    private final UserRepository userRepository;
    private final CourseSectionRepository sectionRepository;
    private final CourseFileRepository fileRepository;
    private final SectionContentRepository sectionContentRepository;
    private final SectionAiConfigRepository aiConfigRepository;
    private final FileMetadataRepository fileMetadataRepository;

    public CourseService(CourseRepository courseRepository,
                         CourseMemberRepository courseMemberRepository,
                         UserRepository userRepository,
                         CourseSectionRepository sectionRepository,
                         CourseFileRepository fileRepository,
                         SectionContentRepository sectionContentRepository,
                         SectionAiConfigRepository aiConfigRepository,
                         FileMetadataRepository fileMetadataRepository) {
        this.courseRepository = courseRepository;
        this.courseMemberRepository = courseMemberRepository;
        this.userRepository = userRepository;
        this.sectionRepository = sectionRepository;
        this.fileRepository = fileRepository;
        this.sectionContentRepository = sectionContentRepository;
        this.aiConfigRepository = aiConfigRepository;
        this.fileMetadataRepository = fileMetadataRepository;
    }

    // ==================== 课程列表 (分页) ====================

    public CourseListResponse getVisibleCoursesPaged(User user, int page, String keyword, Long schoolFilter) {
        // 如果未登录 (user == null)，仅返回 PUBLIC 课程，且不限制学校
        if (user == null) {
            Page<Course> publicCourses = courseRepository.findPublicCoursesPaged(keyword, PageRequest.of(page - 1, 20));
            CourseListResponse response = new CourseListResponse();
            response.setTotal(publicCourses.getTotalElements());
            List<CourseListResponse.CourseListItem> items = new ArrayList<>();
            for (Course c : publicCourses.getContent()) {
                items.add(toCourseListItem(c, null));
            }
            response.setList(items);
            return response;
        }

        if (user.getRole() == Role.TEACHER) {
            // 教师看自己创建的课程 (简单实现, 暂不分页)
            List<Course> all = courseRepository.findByTeacherId(user.getId());
            CourseListResponse response = new CourseListResponse();
            response.setTotal(all.size());
            List<CourseListResponse.CourseListItem> items = new ArrayList<>();
            for (Course c : all) {
                items.add(toCourseListItem(c, user));
            }
            response.setList(items);
            return response;
        }

        Page<Course> coursePage = courseRepository.findVisibleCoursesForStudentPaged(
                user.getSchoolId(), keyword, schoolFilter, PageRequest.of(page - 1, 20));

        CourseListResponse response = new CourseListResponse();
        response.setTotal(coursePage.getTotalElements());
        List<CourseListResponse.CourseListItem> items = new ArrayList<>();
        for (Course c : coursePage.getContent()) {
            items.add(toCourseListItem(c, user));
        }
        response.setList(items);
        return response;
    }

    private CourseListResponse.CourseListItem toCourseListItem(Course c) {
        return toCourseListItem(c, null);
    }

    private CourseListResponse.CourseListItem toCourseListItem(Course c, User currentUser) {
        CourseListResponse.CourseListItem item = new CourseListResponse.CourseListItem();
        item.setId(c.getId());
        item.setTitle(c.getTitle());
        item.setCoverImage(c.getCoverImage());
        item.setStatus(c.getStatus().name());
        item.setVisibility(c.getVisibility().name());
        item.setPermission(c.getPermission().name());
        // 查教师昵称
        userRepository.findById(c.getTeacherId()).ifPresent(t -> item.setTeacherName(t.getNickname()));
        // 填充 is_joined / is_owner
        if (currentUser != null) {
            boolean isOwner = c.getTeacherId().equals(currentUser.getId());
            item.setOwner(isOwner);
            if (isOwner) {
                item.setJoined(true);
            } else {
                boolean joined = courseMemberRepository.findByCourseIdAndUserId(c.getId(), currentUser.getId())
                        .map(m -> m.getStatus() == CourseMember.MemberStatus.JOINED)
                        .orElse(false);
                item.setJoined(joined);
            }
        } else {
            item.setJoined(false);
            item.setOwner(false);
        }
        return item;
    }

    // ==================== 旧版列表 (兼容) ====================

    public List<Course> getVisibleCourses(User user) {
        if (user.getRole() == Role.TEACHER) {
            return courseRepository.findByTeacherId(user.getId());
        } else {
            return courseRepository.findVisibleCoursesForStudent(user.getSchoolId());
        }
    }

    // ==================== 创建课程 ====================

    public Course createCourse(CreateCourseRequest request, User teacher) {
        if (teacher.getRole() != Role.TEACHER) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "只有教师可以创建课程");
        }
        Course course = new Course();
        course.setTeacherId(teacher.getId());
        course.setSchoolId(request.getSchoolId() != null ? request.getSchoolId()
                : (teacher.getSchoolId() != null ? teacher.getSchoolId() : 1L));
        course.setTitle(request.getTitle());
        course.setDescription(request.getDescription());
        course.setCoverImage(request.getCoverImage());
        course.setCreatedAt(LocalDateTime.now());
        course.setUpdatedAt(LocalDateTime.now());
        Course saved = courseRepository.save(course);
        // 自动创建三个默认栏目
        _initDefaultSections(saved.getId());
        return saved;
    }

    private void _initDefaultSections(Long courseId) {
        // 讲义 (DISPLAY)
        CourseSection display = new CourseSection();
        display.setCourseId(courseId);
        display.setTitle("讲义");
        display.setType(CourseSection.SectionType.DISPLAY);
        display.setOrderIndex(0);
        CourseSection savedDisplay = sectionRepository.save(display);
        SectionContent content = new SectionContent();
        content.setSectionId(savedDisplay.getId());
        content.setContent("# 课程讲义\n\n请在此编辑课程内容。");
        sectionContentRepository.save(content);

        // 资料 (STORAGE)
        CourseSection storage = new CourseSection();
        storage.setCourseId(courseId);
        storage.setTitle("资料");
        storage.setType(CourseSection.SectionType.STORAGE);
        storage.setOrderIndex(1);
        sectionRepository.save(storage);

        // AI 助教 (AI)
        CourseSection ai = new CourseSection();
        ai.setCourseId(courseId);
        ai.setTitle("AI 助教");
        ai.setType(CourseSection.SectionType.AI);
        ai.setOrderIndex(2);
        CourseSection savedAi = sectionRepository.save(ai);
        SectionAiConfig aiConfig = new SectionAiConfig();
        aiConfig.setSectionId(savedAi.getId());
        aiConfig.setPageNumber(1);
        aiConfig.setPrompt("你是一个友好且专业的AI助教，帮助学生解答课程相关问题。");
        aiConfig.setGeneratedDsl("{}");
        aiConfigRepository.save(aiConfig);
    }

    // 旧版兼容
    public Course createCourse(Course course, User teacher) {
        if (teacher.getRole() != Role.TEACHER) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "只有教师可以创建课程");
        }
        course.setTeacherId(teacher.getId());
        course.setSchoolId(teacher.getSchoolId());
        course.setCreatedAt(LocalDateTime.now());
        course.setUpdatedAt(LocalDateTime.now());
        return courseRepository.save(course);
    }

    // ==================== 删除课程 ====================

    @Transactional
    public void deleteCourse(Long courseId, User teacher) {
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "课程不存在"));
        if (!course.getTeacherId().equals(teacher.getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "无权删除此课程");
        }

        List<CourseSection> sections = sectionRepository.findByCourseIdOrderByOrderIndexAsc(courseId);
        List<Long> sectionIds = sections.stream().map(CourseSection::getId).toList();

        courseMemberRepository.deleteByCourseId(courseId);
        fileMetadataRepository.deleteByBusinessIdAndUsage(courseId, FileUsage.COURSE_COVER);
        fileMetadataRepository.deleteByBusinessIdAndUsage(courseId, FileUsage.COURSE_MATERIAL);
        if (!sectionIds.isEmpty()) {
            fileMetadataRepository.deleteBySectionIdIn(sectionIds);
        }

        courseRepository.delete(course);
    }

    // ==================== 课程详情 ====================

    /** 获取课程 Entity（内部使用） */
    public Course getCourseEntity(Long courseId) {
        return courseRepository.findById(courseId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "课程不存在"));
    }

    public CourseDetailResponse getCourseDetail(Long courseId, User user) {
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "课程不存在"));

        // 如果不是创建者且课程状态为 PRE_RELEASE/HIDDEN, 拒绝访问
        if (!course.getTeacherId().equals(user.getId())) {
            if (course.getStatus() == Course.CourseStatus.PRE_RELEASE
                    || course.getStatus() == Course.CourseStatus.HIDDEN) {
                throw new ResponseStatusException(HttpStatus.FORBIDDEN, "该课程已下架或转为私密");
            }
        }

        CourseDetailResponse detail = new CourseDetailResponse();
        detail.setId(course.getId());
        detail.setTitle(course.getTitle());
        detail.setIntro(course.getDescription());
        detail.setCoverImage(course.getCoverImage());
        detail.setStatus(course.getStatus().name());
        detail.setVisibility(course.getVisibility().name());
        detail.setPermission(course.getPermission().name());

        userRepository.findById(course.getTeacherId())
                .ifPresent(t -> detail.setTeacherName(t.getNickname()));

        boolean isOwner = course.getTeacherId().equals(user.getId());
        detail.setOwner(isOwner);

        boolean joined = isOwner || courseMemberRepository.findByCourseIdAndUserId(courseId, user.getId())
                .map(m -> m.getStatus() == CourseMember.MemberStatus.JOINED)
                .orElse(false);
        detail.setJoined(joined);

        // 构建 stats 嵌套对象
        long studentCount = courseMemberRepository.findByCourseIdAndStatus(courseId, CourseMember.MemberStatus.JOINED).size();
        long resourceCount = 0;
        List<CourseSection> sections = sectionRepository.findByCourseIdOrderByOrderIndexAsc(courseId);
        for (CourseSection section : sections) {
            if (section.getType() == CourseSection.SectionType.STORAGE) {
                resourceCount += fileRepository.countFilesBySectionId(section.getId());
            }
        }
        CourseDetailResponse.CourseStats stats = new CourseDetailResponse.CourseStats();
        stats.setStudentCount(studentCount);
        stats.setResourceCount(resourceCount);
        detail.setStats(stats);

        return detail;
    }

    // ==================== 更新课程设置 ====================

    public void updateCourseSettings(Long courseId, CourseSettingsRequest request, User teacher) {
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "课程不存在"));
        if (!course.getTeacherId().equals(teacher.getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "无权操作此课程");
        }
        if (request.getTitle() != null && !request.getTitle().isBlank()) {
            course.setTitle(request.getTitle());
        }
        if (request.getDescription() != null) {
            course.setDescription(request.getDescription());
        }
        if (request.getCoverImage() != null) {
            course.setCoverImage(request.getCoverImage());
        }
        if (request.getStatus() != null) {
            course.setStatus(request.getStatus());
        }
        if (request.getVisibility() != null) {
            course.setVisibility(request.getVisibility());
        }
        if (request.getPermission() != null) {
            course.setPermission(request.getPermission());
        }
        course.setUpdatedAt(LocalDateTime.now());
        courseRepository.save(course);
    }

    // ==================== 加入/申请课程 ====================

    public Map<String, Object> enrollCourse(Long courseId, User student, String applyReason) {
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "课程不存在"));

        // 教师不能加入课程（只有学生身份可以加入）
        if (student.getRole() == Role.TEACHER) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "教师身份无法加入课程");
        }

        // 课程创建者不能加入自己的课程
        if (course.getTeacherId().equals(student.getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "不能加入自己创建的课程");
        }

        if (courseMemberRepository.findByCourseIdAndUserId(courseId, student.getId()).isPresent()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "已在课程中或已提交申请");
        }

        CourseMember member = new CourseMember();
        member.setCourseId(courseId);
        member.setUserId(student.getId());
        member.setApplyReason(applyReason);

        Map<String, Object> result = new HashMap<>();
        if (course.getPermission() == Course.CoursePermission.OPEN) {
            member.setStatus(CourseMember.MemberStatus.JOINED);
            member.setApprovedAt(LocalDateTime.now());
            result.put("status", "JOINED");
        } else {
            member.setStatus(CourseMember.MemberStatus.PENDING);
            result.put("status", "PENDING_APPROVAL");
        }

        courseMemberRepository.save(member);
        return result;
    }

    // 旧版兼容
    public void joinCourse(Long courseId, User student, String reason) {
        enrollCourse(courseId, student, reason);
    }

    // ==================== 审核学生申请 ====================

    public void auditApplication(Long courseId, Long memberId, String action, User teacher) {
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "课程不存在"));
        if (!course.getTeacherId().equals(teacher.getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "无权操作此课程");
        }

        CourseMember member = courseMemberRepository.findById(memberId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "未找到申请记录"));
        if (!member.getCourseId().equals(courseId)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "申请记录不属于此课程");
        }

        if ("APPROVE".equalsIgnoreCase(action)) {
            member.setStatus(CourseMember.MemberStatus.JOINED);
            member.setApprovedAt(LocalDateTime.now());
            courseMemberRepository.save(member);
        } else if ("REJECT".equalsIgnoreCase(action)) {
            courseMemberRepository.delete(member);
        } else {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "action 必须为 APPROVE 或 REJECT");
        }
    }

    // 旧版兼容
    public void approveMember(Long courseId, Long studentId, User teacher) {
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "课程不存在"));
        if (!course.getTeacherId().equals(teacher.getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "无权操作此课程");
        }
        CourseMember member = courseMemberRepository.findByCourseIdAndUserId(courseId, studentId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "未找到申请记录"));
        member.setStatus(CourseMember.MemberStatus.JOINED);
        member.setApprovedAt(LocalDateTime.now());
        courseMemberRepository.save(member);
    }

    // ==================== 学生管理 ====================

    public Map<String, Object> getStudentList(Long courseId, String status, int page, int pageSize, User teacher) {
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "课程不存在"));
        if (!course.getTeacherId().equals(teacher.getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "无权操作此课程");
        }

        List<CourseMember> members;
        if (status != null && !status.isBlank()) {
            members = courseMemberRepository.findByCourseIdAndStatus(courseId, CourseMember.MemberStatus.valueOf(status));
        } else {
            // 获取所有成员
            members = new ArrayList<>();
            members.addAll(courseMemberRepository.findByCourseIdAndStatus(courseId, CourseMember.MemberStatus.JOINED));
            members.addAll(courseMemberRepository.findByCourseIdAndStatus(courseId, CourseMember.MemberStatus.PENDING));
        }

        // 手动分页
        int start = (page - 1) * pageSize;
        int end = Math.min(start + pageSize, members.size());
        List<CourseMember> paged = start < members.size() ? members.subList(start, end) : List.of();

        List<Map<String, Object>> list = new ArrayList<>();
        for (CourseMember m : paged) {
            Map<String, Object> item = new HashMap<>();
            item.put("id", m.getId());
            item.put("user_id", m.getUserId());
            item.put("status", m.getStatus().name());
            item.put("apply_reason", m.getApplyReason());
            item.put("joined_at", m.getApprovedAt());
            item.put("created_at", m.getCreatedAt());
            userRepository.findById(m.getUserId()).ifPresent(u -> {
                item.put("nickname", u.getNickname());
                item.put("username", u.getUsername());
                item.put("phone", u.getPhone());
            });
            list.add(item);
        }

        Map<String, Object> result = new HashMap<>();
        result.put("total", members.size());
        result.put("list", list);
        return result;
    }

    public void removeStudent(Long courseId, Long studentId, User teacher) {
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "课程不存在"));
        if (!course.getTeacherId().equals(teacher.getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "无权操作此课程");
        }
        CourseMember member = courseMemberRepository.findByCourseIdAndUserId(courseId, studentId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "该学生不在课程中"));
        courseMemberRepository.delete(member);
    }

    public void inviteStudent(Long courseId, String username, User teacher) {
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "课程不存在"));
        if (!course.getTeacherId().equals(teacher.getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "无权操作此课程");
        }
        User student = userRepository.findByUsername(username)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "用户不存在"));

        if (courseMemberRepository.findByCourseIdAndUserId(courseId, student.getId()).isPresent()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "该学生已在课程中");
        }

        CourseMember member = new CourseMember();
        member.setCourseId(courseId);
        member.setUserId(student.getId());
        member.setStatus(CourseMember.MemberStatus.JOINED);
        member.setApprovedAt(LocalDateTime.now());
        courseMemberRepository.save(member);
    }

    public Map<String, Object> searchStudents(Long courseId, String keyword, User teacher) {
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "课程不存在"));
        if (!course.getTeacherId().equals(teacher.getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "无权操作此课程");
        }

        // 搜索用户名或昵称包含关键词的学生
        List<User> students = userRepository.findByNicknameContainingOrUsernameContaining(keyword, keyword);
        
        List<Map<String, Object>> list = new ArrayList<>();
        for (User s : students) {
            // 检查是否已在课程中
            boolean alreadyJoined = courseMemberRepository.findByCourseIdAndUserId(courseId, s.getId()).isPresent();
            
            Map<String, Object> item = new HashMap<>();
            item.put("id", s.getId());
            item.put("username", s.getUsername());
            item.put("nickname", s.getNickname());
            item.put("phone", s.getPhone());
            item.put("already_joined", alreadyJoined);
            list.add(item);
        }

        Map<String, Object> result = new HashMap<>();
        result.put("total", list.size());
        result.put("list", list);
        return result;
    }
}
