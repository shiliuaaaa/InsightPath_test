package com.example.demo.course.repository;

import com.example.demo.course.entity.CourseSection;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface CourseSectionRepository extends JpaRepository<CourseSection, Long> {

    // 查询课程的所有栏目（按顺序）
    List<CourseSection> findByCourseIdOrderByOrderIndexAsc(Long courseId);

    // 查询课程的可见栏目
    List<CourseSection> findByCourseIdAndIsHiddenOrderByOrderIndexAsc(Long courseId, Boolean isHidden);
}

