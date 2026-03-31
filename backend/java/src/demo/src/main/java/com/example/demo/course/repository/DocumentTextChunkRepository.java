package com.example.demo.course.repository;

import com.example.demo.course.entity.DocumentTextChunk;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface DocumentTextChunkRepository extends JpaRepository<DocumentTextChunk, Long> {

    // 根据关联的 CourseFile 查找所有有效的文本块
    List<DocumentTextChunk> findByCourseFile_IdAndIsDeletedFalse(Long fileId);

    // 自定义查询，用于RAG搜索
    @Query("SELECT d FROM DocumentTextChunk d WHERE d.courseFile.course.id = :courseId AND d.isDeleted = false")
    List<DocumentTextChunk> findRelevantChunksByCourseId(@Param("courseId") Long courseId);
}