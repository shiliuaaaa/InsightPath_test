package com.example.demo.course.repository;

import com.example.demo.course.entity.Course;
import com.example.demo.course.entity.CourseStatus;
import com.example.demo.course.entity.CourseVisibility;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface CourseRepository extends JpaRepository<Course, Long> {

    // 根据教师ID查询课程
    List<Course> findByTeacherId(Long teacherId);

    // 根据学校ID查询课程
    Page<Course> findBySchoolId(Long schoolId, Pageable pageable);

    // 查询公开课程（学生端）
    @Query("SELECT c FROM Course c WHERE c.status IN :statuses AND c.visibility = :visibility")
    Page<Course> findByStatusInAndVisibility(
            @Param("statuses") List<CourseStatus> statuses,
            @Param("visibility") CourseVisibility visibility,
            Pageable pageable
    );

    // 根据学校和可见性查询课程
    @Query("SELECT c FROM Course c WHERE c.schoolId = :schoolId AND c.status IN :statuses AND c.visibility IN :visibilities")
    Page<Course> findBySchoolIdAndStatusInAndVisibilityIn(
            @Param("schoolId") Long schoolId,
            @Param("statuses") List<CourseStatus> statuses,
            @Param("visibilities") List<CourseVisibility> visibilities,
            Pageable pageable
    );

    // 搜索课程（按标题）
    @Query("SELECT c FROM Course c WHERE c.title LIKE %:keyword% AND c.status IN :statuses")
    Page<Course> searchByKeyword(
            @Param("keyword") String keyword,
            @Param("statuses") List<CourseStatus> statuses,
            Pageable pageable
    );
}

