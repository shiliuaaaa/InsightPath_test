package com.example.demo.course.repository;

import com.example.demo.course.entity.AiChatMessage;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface AiChatMessageRepository extends JpaRepository<AiChatMessage, Long> {

    Page<AiChatMessage> findBySectionIdAndUserIdOrderByCreatedAtDesc(Long sectionId, Long userId, Pageable pageable);

    void deleteBySectionIdAndUserId(Long sectionId, Long userId);

    long countBySectionIdAndUserId(Long sectionId, Long userId);
}
