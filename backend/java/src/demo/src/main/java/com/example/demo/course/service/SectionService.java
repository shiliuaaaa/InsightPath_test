package com.example.demo.course.service;

import com.example.demo.auth.entity.User;
import com.example.demo.auth.repository.UserRepository;
import com.example.demo.course.dto.*;
import com.example.demo.course.entity.*;
import com.example.demo.course.repository.*;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class SectionService {

    private final CourseSectionRepository sectionRepository;
    private final SectionContentRepository contentRepository;
    private final CourseFileRepository fileRepository;
    private final SectionAiConfigRepository aiConfigRepository;
    private final AiChatMessageRepository chatMessageRepository;
    private final CourseRepository courseRepository;
    private final UserRepository userRepository;

    public SectionService(CourseSectionRepository sectionRepository,
                          SectionContentRepository contentRepository,
                          CourseFileRepository fileRepository,
                          SectionAiConfigRepository aiConfigRepository,
                          AiChatMessageRepository chatMessageRepository,
                          CourseRepository courseRepository,
                          UserRepository userRepository) {
        this.sectionRepository = sectionRepository;
        this.contentRepository = contentRepository;
        this.fileRepository = fileRepository;
        this.aiConfigRepository = aiConfigRepository;
        this.chatMessageRepository = chatMessageRepository;
        this.courseRepository = courseRepository;
        this.userRepository = userRepository;
    }

    // ==================== 栏目 CRUD ====================

    /** 获取对学生可见的栏目（排除 isHidden），返回文档规范的 DTO */
    public List<SectionResponse> getSections(Long courseId) {
        return sectionRepository.findByCourseIdAndIsHiddenFalseOrderByOrderIndexAsc(courseId)
                .stream().map(this::toSectionResponse).toList();
    }

    /** 获取全部栏目（包含隐藏），返回文档规范的 DTO */
    public List<SectionResponse> getAllSections(Long courseId) {
        return sectionRepository.findByCourseIdOrderByOrderIndexAsc(courseId)
                .stream().map(this::toSectionResponse).toList();
    }

    /** 根据 courseId 查找 type=AI 的 Section（内部使用，返回 Entity） */
    public CourseSection findAiSection(Long courseId) {
        return sectionRepository.findByCourseIdOrderByOrderIndexAsc(courseId).stream()
                .filter(s -> s.getType() == CourseSection.SectionType.AI)
                .findFirst()
                .orElse(null);
    }

    private SectionResponse toSectionResponse(CourseSection s) {
        SectionResponse r = new SectionResponse();
        r.setId(s.getId());
        r.setTitle(s.getTitle());
        r.setType(s.getType().name());
        r.setOrder(s.getOrderIndex());
        r.setIsHidden(s.getIsHidden());
        return r;
    }

    public SectionResponse createSection(Long courseId, CreateSectionRequest request, User teacher) {
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "课程不存在"));
        if (!course.getTeacherId().equals(teacher.getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "无权操作此课程");
        }

        CourseSection section = new CourseSection();
        section.setCourseId(courseId);
        section.setTitle(request.getTitle());
        section.setType(request.getType());
        section.setOrderIndex(request.getOrderIndex() != null ? request.getOrderIndex() : 0);
        CourseSection saved = sectionRepository.save(section);

        // 根据类型自动创建关联记录
        switch (request.getType()) {
            case DISPLAY -> {
                SectionContent content = new SectionContent();
                content.setSectionId(saved.getId());
                content.setContent("");
                contentRepository.save(content);
            }
            case AI -> {
                SectionAiConfig config = new SectionAiConfig();
                config.setSectionId(saved.getId());
                config.setSystemPrompt("你是一个友好的AI助教。");
                aiConfigRepository.save(config);
            }
            default -> { /* STORAGE 不需要初始化 */ }
        }

        return toSectionResponse(saved);
    }

    @Transactional
    public void deleteSection(Long courseId, Long sectionId, User teacher) {
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "课程不存在"));
        if (!course.getTeacherId().equals(teacher.getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "无权操作此课程");
        }
        CourseSection section = sectionRepository.findById(sectionId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "栏目不存在"));
        if (!section.getCourseId().equals(courseId)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "栏目不属于此课程");
        }
        sectionRepository.delete(section);
    }

    // ==================== 显示页面 (DISPLAY) ====================

    public Map<String, Object> getDisplayContent(Long sectionId) {
        CourseSection section = sectionRepository.findById(sectionId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "栏目不存在"));
        if (section.getType() != CourseSection.SectionType.DISPLAY) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "该栏目不是显示页面");
        }

        SectionContent content = contentRepository.findBySectionId(sectionId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "内容不存在"));

        Map<String, Object> result = new HashMap<>();
        result.put("section_id", sectionId);
        result.put("title", section.getTitle());
        result.put("content", content.getContent());
        result.put("updated_at", content.getUpdatedAt());
        return result;
    }

    public Map<String, Object> updateDisplayContent(Long courseId, Long sectionId,
                                                     String newContent, User teacher) {
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "课程不存在"));
        if (!course.getTeacherId().equals(teacher.getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "无权操作此课程");
        }

        SectionContent content = contentRepository.findBySectionId(sectionId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "内容不存在"));
        content.setContent(newContent);
        content.setUpdatedAt(LocalDateTime.now());
        contentRepository.save(content);

        Map<String, Object> result = new HashMap<>();
        result.put("updated_at", content.getUpdatedAt());
        return result;
    }

    // ==================== 存储页面 (STORAGE) - 文件管理 ====================

    public Map<String, Object> getFiles(Long sectionId, Long parentId) {
        List<CourseFile> files;
        if (parentId == null || parentId == 0) {
            files = fileRepository.findBySectionIdAndParentIdIsNullOrderByTypeAscNameAsc(sectionId);
        } else {
            files = fileRepository.findBySectionIdAndParentIdOrderByTypeAscNameAsc(sectionId, parentId);
        }

        // 构建面包屑
        List<Map<String, Object>> path = buildBreadcrumb(parentId);

        // 构建文件列表，为文件夹添加 item_count
        List<Map<String, Object>> fileList = new ArrayList<>();
        for (CourseFile file : files) {
            Map<String, Object> item = new HashMap<>();
            item.put("id", file.getId());
            item.put("type", file.getType().name());
            item.put("name", file.getName());
            item.put("updated_at", file.getCreatedAt());
            if (file.getType() == CourseFile.FileType.FOLDER) {
                item.put("item_count", fileRepository.countByParentId(file.getId()));
            } else {
                item.put("url", file.getFileUrl());
                item.put("size", file.getFileSize());
                item.put("extension", file.getFileExt());
            }
            fileList.add(item);
        }

        Map<String, Object> result = new HashMap<>();
        result.put("current_folder_id", parentId != null ? parentId : 0);
        result.put("path", path);
        result.put("list", fileList);
        return result;
    }

    private List<Map<String, Object>> buildBreadcrumb(Long folderId) {
        List<Map<String, Object>> path = new ArrayList<>();
        Map<String, Object> root = new HashMap<>();
        root.put("id", 0);
        root.put("name", "根目录");
        path.add(root);

        if (folderId == null || folderId == 0) {
            return path;
        }

        // 向上遍历到根
        List<Map<String, Object>> ancestors = new ArrayList<>();
        Long currentId = folderId;
        while (currentId != null && currentId != 0) {
            Long id = currentId;
            CourseFile folder = fileRepository.findById(id).orElse(null);
            if (folder == null) break;
            Map<String, Object> node = new HashMap<>();
            node.put("id", folder.getId());
            node.put("name", folder.getName());
            ancestors.add(0, node);
            currentId = folder.getParentId();
        }
        path.addAll(ancestors);
        return path;
    }

    public CourseFile createFolder(Long sectionId, Long parentId, String name) {
        CourseFile folder = new CourseFile();
        folder.setSectionId(sectionId);
        folder.setParentId(parentId != null && parentId != 0 ? parentId : null);
        folder.setType(CourseFile.FileType.FOLDER);
        folder.setName(name);
        return fileRepository.save(folder);
    }

    @Transactional
    public void deleteFileOrFolder(Long itemId) {
        CourseFile item = fileRepository.findById(itemId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "文件/文件夹不存在"));
        if (item.getType() == CourseFile.FileType.FOLDER) {
            deleteRecursive(itemId);
        }
        fileRepository.delete(item);
    }

    private void deleteRecursive(Long parentId) {
        List<CourseFile> children = fileRepository.findByParentId(parentId);
        for (CourseFile child : children) {
            if (child.getType() == CourseFile.FileType.FOLDER) {
                deleteRecursive(child.getId());
            }
            fileRepository.delete(child);
        }
    }

    public CourseFile renameItem(Long itemId, String newName) {
        CourseFile item = fileRepository.findById(itemId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "文件/文件夹不存在"));
        item.setName(newName);
        return fileRepository.save(item);
    }

    // ==================== AI 配置 ====================

    public Map<String, Object> getAiConfig(Long courseId, Long sectionId, User user) {
        CourseSection section = sectionRepository.findById(sectionId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "栏目不存在"));

        SectionAiConfig config = aiConfigRepository.findBySectionId(sectionId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "AI配置不存在"));

        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "课程不存在"));

        Map<String, Object> result = new HashMap<>();
        result.put("course_id", courseId);
        result.put("ai_name", section.getTitle());
        result.put("ai_avatar", null); // 当前版本暂无自定义头像，预留字段
        result.put("welcome_message", config.getWelcomeMessage());
        result.put("updated_at", config.getUpdatedAt());

        // 仅教师可见 system_prompt
        if (course.getTeacherId().equals(user.getId())) {
            result.put("system_prompt", config.getSystemPrompt());
        } else {
            result.put("system_prompt", null);
        }
        return result;
    }

    public void updateAiConfig(Long courseId, Long sectionId, AiConfigRequest request, User teacher) {
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "课程不存在"));
        if (!course.getTeacherId().equals(teacher.getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "无权操作此课程");
        }

        SectionAiConfig config = aiConfigRepository.findBySectionId(sectionId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "AI配置不存在"));
        config.setWelcomeMessage(request.getWelcomeMessage());
        config.setSystemPrompt(request.getSystemPrompt());
        config.setUpdatedAt(LocalDateTime.now());
        aiConfigRepository.save(config);
    }

    // ==================== AI 对话 ====================

    @Transactional
    public void deleteAiHistory(Long sectionId, Long userId) {
        chatMessageRepository.deleteBySectionIdAndUserId(sectionId, userId);
    }

    public Map<String, Object> getAiHistory(Long sectionId, Long userId, int page, int pageSize) {
        Page<AiChatMessage> msgPage = chatMessageRepository
                .findBySectionIdAndUserIdOrderByCreatedAtDesc(sectionId, userId, PageRequest.of(page - 1, pageSize));

        List<Map<String, Object>> list = new ArrayList<>();
        for (AiChatMessage msg : msgPage.getContent()) {
            Map<String, Object> item = new HashMap<>();
            item.put("id", msg.getId());
            // 文档规范: sender 为 "USER" 或 "AI"
            String sender = msg.getRole() == AiChatMessage.MessageRole.ASSISTANT ? "AI" : "USER";
            item.put("sender", sender);
            item.put("content", msg.getContent());
            item.put("created_at", msg.getCreatedAt());
            list.add(item);
        }

        Map<String, Object> result = new HashMap<>();
        result.put("total", msgPage.getTotalElements());
        result.put("page", page);
        result.put("list", list);
        return result;
    }

    // ==================== 学生管理在 CourseService 中 ====================
}
