package com.example.demo.common.controller;

import com.example.demo.auth.service.JwtService;
import com.example.demo.common.dto.FileAccessRequest;
import com.example.demo.common.dto.FileUploadResponse;
import com.example.demo.common.entity.FileMetadata;
import com.example.demo.common.entity.FileUsage;
import com.example.demo.common.service.FileStorageService;
import com.example.demo.course.entity.CourseFile;
import com.example.demo.course.repository.CourseFileRepository;
import com.example.demo.dto.ApiResponse;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Objects;

@RestController
@RequestMapping("/api/v1/common")
public class CommonFileController {

	private final FileStorageService fileStorageService;
	private final JwtService jwtService;
	private final CourseFileRepository courseFileRepository;

	public CommonFileController(FileStorageService fileStorageService,
								JwtService jwtService,
								CourseFileRepository courseFileRepository) {
		this.fileStorageService = fileStorageService;
		this.jwtService = jwtService;
		this.courseFileRepository = courseFileRepository;
	}

	@PostMapping("/upload")
	public ApiResponse<FileUploadResponse> upload(@RequestParam("file") MultipartFile file,
										 @RequestParam("usage") FileUsage usage,
										 @RequestParam(value = "id", required = false) Long businessId,
										 @RequestParam(value = "section_id", required = false) Long sectionId,
										 @RequestParam(value = "parent_id", required = false) Long parentId) {
		validateUploadParams(usage, businessId, sectionId);
		FileMetadata metadata = fileStorageService.store(file, usage, businessId, sectionId);
		String accessUrl = "/api/v1/common/file/access";

		// 如果是课件上传，同步在 course_files 表创建 FILE 记录
		if (usage == FileUsage.COURSE_MATERIAL && sectionId != null) {
			String originalName = Objects.requireNonNullElse(file.getOriginalFilename(), "unknown");
			String ext = extractExtension(originalName);

			CourseFile courseFile = new CourseFile();
			courseFile.setSectionId(sectionId);
			courseFile.setParentId(parentId != null && parentId != 0 ? parentId : null);
			courseFile.setType(CourseFile.FileType.FILE);
			courseFile.setName(originalName);
			courseFile.setFileUrl(metadata.getStoredName()); // 存储名，前端通过 file/access 接口访问
			courseFile.setFileSize(metadata.getSize());
			courseFile.setFileExt(ext.isEmpty() ? null : ext.substring(1)); // 去掉点号
			courseFileRepository.save(courseFile);
		}

		FileUploadResponse response = new FileUploadResponse(metadata.getStoredName(), accessUrl,
				metadata.getSize(), metadata.getUsage());
		return ApiResponse.success("上传成功", response);
	}

	@GetMapping("/static/{filename}")
	public ResponseEntity<Resource> access(@PathVariable String filename,
										@RequestParam(value = "usage", required = false) String usageStr,
										@RequestParam(value = "id", required = false) Long businessId,
										@RequestParam(value = "section_id", required = false) Long sectionId,
										HttpServletRequest httpRequest) {
		if (!StringUtils.hasText(filename)) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "filename 必填");
		}

		FileUsage usage = FileUsage.AVATAR; // 默认值
		if (StringUtils.hasText(usageStr)) {
			try {
				usage = FileUsage.valueOf(usageStr.toUpperCase());
			} catch (IllegalArgumentException e) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "无效的 usage 参数");
			}
		}

		// 课件需要鉴权
		if (usage == FileUsage.COURSE_MATERIAL) {
			String authorization = httpRequest.getHeader("Authorization");
			if (!StringUtils.hasText(authorization)) {
				throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "缺少有效的Authorization头");
			}
			jwtService.parseToken(jwtService.extractBearerToken(authorization));
		}

		FileMetadata metadata = fileStorageService.loadForAccess(filename, usage);

		Path filePath = Path.of(metadata.getStoragePath());
		if (!Files.exists(filePath)) {
			throw new ResponseStatusException(HttpStatus.NOT_FOUND, "文件不存在或已删除");
		}

		Resource resource = new FileSystemResource(Objects.requireNonNull(filePath.toFile()));
		String contentTypeValue = metadata.getContentType();
		MediaType mediaType = StringUtils.hasText(contentTypeValue)
				? MediaType.parseMediaType(Objects.requireNonNull(contentTypeValue))
				: MediaType.APPLICATION_OCTET_STREAM;
 		MediaType safeMediaType = Objects.requireNonNull(mediaType);

		return ResponseEntity.ok()
				.header(HttpHeaders.CONTENT_DISPOSITION,
						"attachment; filename=\"" + metadata.getOriginalName() + "\"")
				.contentType(safeMediaType)
				.body(resource);
	}

	private void validateUploadParams(FileUsage usage, Long businessId, Long sectionId) {
		if (usage == FileUsage.COURSE_MATERIAL) {
			if (businessId == null || sectionId == null) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "上传课件必须提供 id 与 section_id");
			}
		}
		if (usage == FileUsage.COURSE_COVER && businessId == null) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "上传封面必须提供 id");
		}
	}

	private String extractExtension(String originalName) {
		int lastDot = originalName.lastIndexOf('.');
		if (lastDot < 0 || lastDot == originalName.length() - 1) {
			return "";
		}
		return originalName.substring(lastDot).toLowerCase();
	}
}
