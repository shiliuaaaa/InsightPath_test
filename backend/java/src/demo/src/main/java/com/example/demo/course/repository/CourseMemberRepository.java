package com.example.demo.course.repository;

import com.example.demo.course.entity.CourseMember;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;

@Repository
public interface CourseMemberRepository extends JpaRepository<CourseMember, Long> {
    
    Optional<CourseMember> findByCourseIdAndUserId(Long courseId, Long userId);
    
    List<CourseMember> findByUserId(Long userId);
    
    List<CourseMember> findByCourseIdAndStatus(Long courseId, CourseMember.MemberStatus status);

    void deleteByCourseId(Long courseId);
}
