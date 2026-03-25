package com.example.demo.common.service;

import com.example.demo.common.entity.FileMetadata;
import com.example.demo.common.entity.FileUsage;
import com.example.demo.common.repository.FileMetadataRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.Objects;
import java.util.UUID;

@Service
public class FileStorageService {

	private final Path storageRoot;
	private final FileMetadataRepository fileMetadataRepository;

	public FileStorageService(@Value("${app.file.storage-dir:/tmp/insightpath/uploads}") String storageDir,
							  FileMetadataRepository fileMetadataRepository) {
		this.storageRoot = Path.of(storageDir).toAbsolutePath().normalize();
		this.fileMetadataRepository = fileMetadataRepository;
	}

	public FileMetadata store(MultipartFile file, FileUsage usage, Long businessId, Long sectionId) {
		if (file == null || file.isEmpty()) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "上传文件不能为空");
		}
		String originalName = Objects.requireNonNullElse(file.getOriginalFilename(), "unknown");
		String extension = extractExtension(originalName);
		String storedName = UUID.randomUUID().toString().replace("-", "") + extension;

		Path usageDir = storageRoot.resolve(usage.name().toLowerCase());
		try {
			Files.createDirectories(usageDir);
			Path targetPath = usageDir.resolve(storedName);
			Files.copy(file.getInputStream(), targetPath, StandardCopyOption.REPLACE_EXISTING);

			FileMetadata metadata = new FileMetadata();
			metadata.setOriginalName(originalName);
			metadata.setStoredName(storedName);
			metadata.setUsage(usage);
			metadata.setSize(file.getSize());
			metadata.setContentType(file.getContentType());
			metadata.setBusinessId(businessId);
			metadata.setSectionId(sectionId);
			metadata.setStoragePath(targetPath.toString());
			return fileMetadataRepository.save(metadata);
		} catch (IOException ex) {
			throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "文件保存失败");
		}
	}

	public FileMetadata loadForAccess(String storedName, FileUsage usage) {
		return fileMetadataRepository.findByStoredNameAndUsage(storedName, usage)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "文件不存在或已删除"));
	}

	private String extractExtension(String originalName) {
		int lastDot = originalName.lastIndexOf('.');
		if (lastDot < 0 || lastDot == originalName.length() - 1) {
			return "";
		}
		return originalName.substring(lastDot).toLowerCase();
	}
}
