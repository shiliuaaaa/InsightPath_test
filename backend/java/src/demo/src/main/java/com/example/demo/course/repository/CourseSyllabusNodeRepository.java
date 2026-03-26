package com.example.demo.course.repository;

import com.example.demo.course.entity.CourseSyllabusNode;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface CourseSyllabusNodeRepository extends JpaRepository<CourseSyllabusNode, Long> {

    List<CourseSyllabusNode> findByCourseIdAndParentIdIsNullOrderByOrderIndexAscIdAsc(Long courseId);

    List<CourseSyllabusNode> findByCourseIdAndParentIdOrderByOrderIndexAscIdAsc(Long courseId, Long parentId);

    long countByCourseIdAndParentId(Long courseId, Long parentId);

    long countByCourseIdAndParentIdIsNull(Long courseId);
}

