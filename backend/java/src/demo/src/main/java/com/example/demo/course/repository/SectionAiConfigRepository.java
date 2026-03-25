package com.example.demo.course.repository;

import com.example.demo.course.entity.SectionAiConfig;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.Optional;

@Repository
public interface SectionAiConfigRepository extends JpaRepository<SectionAiConfig, Long> {

    Optional<SectionAiConfig> findBySectionId(Long sectionId);
}
