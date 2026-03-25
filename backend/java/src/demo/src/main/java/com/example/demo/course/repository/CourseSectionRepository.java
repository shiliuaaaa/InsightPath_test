package com.example.demo.course.repository;

import com.example.demo.course.entity.CourseSection;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface CourseSectionRepository extends JpaRepository<CourseSection, Long> {

    List<CourseSection> findByCourseIdOrderByOrderIndexAsc(Long courseId);

    List<CourseSection> findByCourseIdAndIsHiddenFalseOrderByOrderIndexAsc(Long courseId);
}
