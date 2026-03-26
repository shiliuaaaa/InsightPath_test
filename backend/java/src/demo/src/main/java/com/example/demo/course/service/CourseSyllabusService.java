package com.example.demo.course.service;

import com.example.demo.auth.entity.User;
import com.example.demo.common.entity.FileMetadata;
import com.example.demo.common.entity.FileUsage;
import com.example.demo.common.repository.FileMetadataRepository;
import com.example.demo.course.dto.*;
import com.example.demo.course.entity.Course;
import com.example.demo.course.entity.CourseFile;
import com.example.demo.course.entity.CourseSyllabusNode;
import com.example.demo.course.repository.CourseFileRepository;
import com.example.demo.course.repository.CourseRepository;
import com.example.demo.course.repository.CourseSyllabusNodeRepository;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
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
public class CourseSyllabusService {

    private final CourseRepository courseRepository;
    private final CourseFileRepository courseFileRepository;
    private final CourseSyllabusNodeRepository syllabusNodeRepository;
    private final FileMetadataRepository fileMetadataRepository;
    private final ObjectMapper objectMapper;

    public CourseSyllabusService(CourseRepository courseRepository,
                                 CourseFileRepository courseFileRepository,
                                 CourseSyllabusNodeRepository syllabusNodeRepository,
                                 FileMetadataRepository fileMetadataRepository,
                                 ObjectMapper objectMapper) {
        this.courseRepository = courseRepository;
        this.courseFileRepository = courseFileRepository;
        this.syllabusNodeRepository = syllabusNodeRepository;
        this.fileMetadataRepository = fileMetadataRepository;
        this.objectMapper = objectMapper;
    }

    public List<SyllabusNodeResponse> getSyllabusTree(Long courseId) {
        ensureCourseExists(courseId);
        List<CourseSyllabusNode> chapters = syllabusNodeRepository.findByCourseIdAndParentIdIsNullOrderByOrderIndexAscIdAsc(courseId);
        List<SyllabusNodeResponse> result = new ArrayList<>();
        for (CourseSyllabusNode chapter : chapters) {
            result.add(toTreeNode(courseId, chapter));
        }
        return result;
    }

    @Transactional
    public SyllabusNodeResponse createChapter(Long courseId, CreateSyllabusChapterRequest body, User teacher) {
        ensureTeacherOwner(courseId, teacher);
        if (body.getTitle() == null || body.getTitle().isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "章节名称不能为空");
        }

        CourseSyllabusNode node = new CourseSyllabusNode();
        node.setCourseId(courseId);
        node.setParentId(null);
        node.setType(CourseSyllabusNode.NodeType.CHAPTER);
        node.setTitle(body.getTitle().trim());
        node.setOrderIndex((int) syllabusNodeRepository.countByCourseIdAndParentIdIsNull(courseId));
        node.setUpdatedAt(LocalDateTime.now());

        return toTreeNode(courseId, syllabusNodeRepository.save(node));
    }

    @Transactional
    public SyllabusNodeResponse createKnowledge(Long courseId, Long chapterId, CreateSyllabusKnowledgeRequest body, User teacher) {
        ensureTeacherOwner(courseId, teacher);
        CourseSyllabusNode chapter = requireChapter(courseId, chapterId);

        if (body.getTitle() == null || body.getTitle().isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "知识点名称不能为空");
        }
        if (body.getResourceFileId() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "知识点必须关联一个资料文件");
        }

        CourseFile file = courseFileRepository.findById(body.getResourceFileId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "关联文件不存在"));
        if (file.getType() != CourseFile.FileType.FILE) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "只能关联文件，不能关联文件夹");
        }

        CourseSyllabusNode node = new CourseSyllabusNode();
        node.setCourseId(courseId);
        node.setParentId(chapter.getId());
        node.setType(CourseSyllabusNode.NodeType.KNOWLEDGE);
        node.setTitle(body.getTitle().trim());
        node.setResourceFileId(body.getResourceFileId());
        node.setOrderIndex((int) syllabusNodeRepository.countByCourseIdAndParentId(courseId, chapter.getId()));
        node.setUpdatedAt(LocalDateTime.now());

        return toTreeNode(courseId, syllabusNodeRepository.save(node));
    }

    @Transactional
    public SyllabusNodeResponse createQuiz(Long courseId, Long chapterId, CreateSyllabusQuizRequest body, User teacher) {
        ensureTeacherOwner(courseId, teacher);
        CourseSyllabusNode chapter = requireChapter(courseId, chapterId);

        if (body.getQuestion() == null || body.getQuestion().isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "题目不能为空");
        }
        if (body.getAnswer() == null || body.getAnswer().isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "答案不能为空");
        }

        String typeRaw = body.getQuizType() == null ? "" : body.getQuizType().trim().toUpperCase();
        CourseSyllabusNode.NodeType type;
        if ("CHOICE".equals(typeRaw)) {
            type = CourseSyllabusNode.NodeType.QUIZ_CHOICE;
            if (body.getOptions() == null || body.getOptions().isEmpty()) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "选择题至少需要一个选项");
            }
        } else if ("ESSAY".equals(typeRaw)) {
            type = CourseSyllabusNode.NodeType.QUIZ_ESSAY;
        } else {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "quiz_type 仅支持 CHOICE 或 ESSAY");
        }

        CourseSyllabusNode node = new CourseSyllabusNode();
        node.setCourseId(courseId);
        node.setParentId(chapter.getId());
        node.setType(type);
        node.setTitle(type == CourseSyllabusNode.NodeType.QUIZ_CHOICE ? "选择题" : "大题");
        node.setQuestionText(body.getQuestion().trim());
        node.setAnswerText(body.getAnswer().trim());
        if (type == CourseSyllabusNode.NodeType.QUIZ_CHOICE) {
            try {
                node.setOptionsJson(objectMapper.writeValueAsString(body.getOptions()));
            } catch (Exception e) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "选项格式错误");
            }
        }
        node.setOrderIndex((int) syllabusNodeRepository.countByCourseIdAndParentId(courseId, chapter.getId()));
        node.setUpdatedAt(LocalDateTime.now());

        return toTreeNode(courseId, syllabusNodeRepository.save(node));
    }

    private Course ensureCourseExists(Long courseId) {
        return courseRepository.findById(courseId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "课程不存在"));
    }

    private void ensureTeacherOwner(Long courseId, User teacher) {
        Course course = ensureCourseExists(courseId);
        if (!course.getTeacherId().equals(teacher.getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "无权操作此课程大纲");
        }
    }

    private CourseSyllabusNode requireChapter(Long courseId, Long chapterId) {
        CourseSyllabusNode node = syllabusNodeRepository.findById(chapterId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "章节不存在"));
        if (!node.getCourseId().equals(courseId) || node.getType() != CourseSyllabusNode.NodeType.CHAPTER) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "chapterId 无效");
        }
        return node;
    }

    private SyllabusNodeResponse toTreeNode(Long courseId, CourseSyllabusNode node) {
        SyllabusNodeResponse res = toNode(courseId, node);
        if (node.getType() == CourseSyllabusNode.NodeType.CHAPTER) {
            List<CourseSyllabusNode> children = syllabusNodeRepository.findByCourseIdAndParentIdOrderByOrderIndexAscIdAsc(courseId, node.getId());
            List<SyllabusNodeResponse> childViews = new ArrayList<>();
            for (CourseSyllabusNode child : children) {
                childViews.add(toNode(courseId, child));
            }
            res.setChildren(childViews);
        }
        return res;
    }

    private SyllabusNodeResponse toNode(Long courseId, CourseSyllabusNode node) {
        SyllabusNodeResponse res = new SyllabusNodeResponse();
        res.setId(node.getId());
        res.setParentId(node.getParentId());
        res.setType(node.getType().name());
        res.setTitle(node.getTitle());
        res.setResourceFileId(node.getResourceFileId());
        res.setQuestion(node.getQuestionText());
        res.setAnswer(node.getAnswerText());

        if (node.getOptionsJson() != null && !node.getOptionsJson().isBlank()) {
            try {
                List<QuizOptionDto> options = objectMapper.readValue(node.getOptionsJson(), new TypeReference<List<QuizOptionDto>>() {});
                res.setOptions(options);
            } catch (Exception ignore) {
                res.setOptions(new ArrayList<>());
            }
        }

        if (node.getResourceFileId() != null) {
            CourseFile file = courseFileRepository.findById(node.getResourceFileId()).orElse(null);
            if (file != null) {
                res.setResourceName(file.getName());
                res.setResourceExtension(file.getFileExt());
                res.setResourcePdfUrl(file.getPdfUrl());
                res.setResourceUrl(file.getFileUrl());
            }
        }

        return res;
    }
}

