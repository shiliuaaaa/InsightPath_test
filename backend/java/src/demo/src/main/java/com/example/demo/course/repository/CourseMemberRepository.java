package com.example.demo.course.repository;

import com.example.demo.course.entity.CourseMember;
import com.example.demo.course.entity.MemberStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface CourseMemberRepository extends JpaRepository<CourseMember, Long> {

    // 检查用户是否已加入课程
    boolean existsByCourseIdAndUserId(Long courseId, Long userId);

    // 查询用户在课程中的成员记录
    Optional<CourseMember> findByCourseIdAndUserId(Long courseId, Long userId);

    // 查询课程的所有成员（分页）
    Page<CourseMember> findByCourseIdAndStatus(Long courseId, MemberStatus status, Pageable pageable);

    // 查询课程的待审核申请
    Page<CourseMember> findByCourseId(Long courseId, Pageable pageable);
}

