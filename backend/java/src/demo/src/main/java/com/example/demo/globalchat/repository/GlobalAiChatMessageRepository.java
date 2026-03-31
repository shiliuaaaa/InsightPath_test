package com.example.demo.globalchat.repository;

import com.example.demo.globalchat.entity.AiChatMessage;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository("globalAiChatMessageRepository")
public interface GlobalAiChatMessageRepository extends JpaRepository<AiChatMessage, Long> {

    List<AiChatMessage> findBySessionIdOrderByCreatedAtAsc(Long sessionId);
}

