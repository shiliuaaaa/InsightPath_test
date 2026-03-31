package com.example.demo.course.repository;

import com.example.demo.course.entity.SectionAiConfig;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface SectionAiConfigRepository extends JpaRepository<SectionAiConfig, Long> {

    List<SectionAiConfig> findBySectionIdOrderByPageNumberAscUpdatedAtDesc(Long sectionId);

    Optional<SectionAiConfig> findFirstBySectionIdOrderByUpdatedAtDesc(Long sectionId);

    void deleteBySectionIdAndPageNumber(Long sectionId, Integer pageNumber);
}
