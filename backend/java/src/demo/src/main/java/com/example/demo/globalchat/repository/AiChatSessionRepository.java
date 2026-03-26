package com.example.demo.globalchat.repository;

import com.example.demo.globalchat.entity.AiChatSession;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface AiChatSessionRepository extends JpaRepository<AiChatSession, Long> {

    List<AiChatSession> findByUserIdOrderByUpdatedAtDesc(Long userId);
}

