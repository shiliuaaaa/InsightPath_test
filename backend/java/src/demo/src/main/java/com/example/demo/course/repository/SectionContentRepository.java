package com.example.demo.course.repository;

import com.example.demo.course.entity.SectionContent;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.Optional;

@Repository
public interface SectionContentRepository extends JpaRepository<SectionContent, Long> {

    Optional<SectionContent> findBySectionId(Long sectionId);
}
