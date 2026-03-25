package com.example.demo.course.repository;

import com.example.demo.course.entity.Course;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface CourseRepository extends JpaRepository<Course, Long> {
    
    List<Course> findByTeacherId(Long teacherId);

    @Query("SELECT c FROM Course c WHERE c.status = 'IN_PROGRESS' AND " +
           "(c.visibility = 'PUBLIC' OR (c.visibility = 'RESTRICTED' AND c.schoolId = :schoolId))")
    List<Course> findVisibleCoursesForStudent(@Param("schoolId") Long schoolId);

    @Query(value = "SELECT * FROM courses c WHERE c.status IN ('IN_PROGRESS', 'COMPLETED') " +
           "AND (c.visibility = 'PUBLIC' OR (c.visibility = 'RESTRICTED' AND c.school_id = :schoolId)) " +
           "AND (:keyword IS NULL OR LOWER(c.title) LIKE LOWER(CONCAT('%', CAST(:keyword AS text), '%'))) " +
           "AND (:schoolFilter IS NULL OR c.school_id = CAST(:schoolFilter AS bigint))",
           countQuery = "SELECT COUNT(*) FROM courses c WHERE c.status IN ('IN_PROGRESS', 'COMPLETED') " +
           "AND (c.visibility = 'PUBLIC' OR (c.visibility = 'RESTRICTED' AND c.school_id = :schoolId)) " +
           "AND (:keyword IS NULL OR LOWER(c.title) LIKE LOWER(CONCAT('%', CAST(:keyword AS text), '%'))) " +
           "AND (:schoolFilter IS NULL OR c.school_id = CAST(:schoolFilter AS bigint))",
           nativeQuery = true)
    Page<Course> findVisibleCoursesForStudentPaged(
            @Param("schoolId") Long schoolId,
            @Param("keyword") String keyword,
            @Param("schoolFilter") Long schoolFilter,
            Pageable pageable);

    @Query(value = "SELECT * FROM courses c WHERE c.status IN ('IN_PROGRESS', 'COMPLETED') " +
           "AND c.visibility = 'PUBLIC' " +
           "AND (:keyword IS NULL OR LOWER(c.title) LIKE LOWER(CONCAT('%', CAST(:keyword AS text), '%')))",
           countQuery = "SELECT COUNT(*) FROM courses c WHERE c.status IN ('IN_PROGRESS', 'COMPLETED') " +
           "AND c.visibility = 'PUBLIC' " +
           "AND (:keyword IS NULL OR LOWER(c.title) LIKE LOWER(CONCAT('%', CAST(:keyword AS text), '%')))",
           nativeQuery = true)
    Page<Course> findPublicCoursesPaged(
            @Param("keyword") String keyword,
            Pageable pageable);
}
