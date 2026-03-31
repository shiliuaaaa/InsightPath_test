package com.example.demo.course.repository;

import com.example.demo.course.entity.CourseFile;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface CourseFileRepository extends JpaRepository<CourseFile, Long> {

    List<CourseFile> findBySectionIdAndParentIdIsNullOrderByTypeAscNameAsc(Long sectionId);

    List<CourseFile> findBySectionIdAndParentIdOrderByTypeAscNameAsc(Long sectionId, Long parentId);

    List<CourseFile> findByParentId(Long parentId);

    @Query("SELECT COUNT(f) FROM CourseFile f WHERE f.parentId = :parentId")
    int countByParentId(@Param("parentId") Long parentId);

    @Query("SELECT COUNT(f) FROM CourseFile f WHERE f.sectionId = :sectionId AND f.type = 'FILE'")
    long countFilesBySectionId(@Param("sectionId") Long sectionId);

    //新增
    @Query("SELECT COUNT(cf) > 0 FROM CourseFile cf JOIN CourseSection cs ON cf.sectionId = cs.id JOIN Course c ON cs.courseId = c.id WHERE cf.id = :fileId AND c.teacherId = :teacherId")
    boolean existsByIdAndSectionCourseTeacherId(@Param("fileId") Long fileId, @Param("teacherId") Long teacherId);
}
