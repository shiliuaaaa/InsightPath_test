package com.example.demo.common.repository;

import com.example.demo.common.entity.FileMetadata;
import com.example.demo.common.entity.FileUsage;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface FileMetadataRepository extends JpaRepository<FileMetadata, Long> {

	Optional<FileMetadata> findByStoredNameAndUsage(String storedName, FileUsage usage);
}
