package com.example.demo.common.service;

import com.example.demo.common.entity.FileMetadata;
import com.example.demo.common.entity.FileUsage;
import com.example.demo.common.repository.FileMetadataRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.List;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import java.util.logging.Logger;

@Service
public class FileStorageService {

	private static final Logger logger = Logger.getLogger(FileStorageService.class.getName());

	private static final Set<String> OFFICE_EXTS = Set.of(".ppt", ".pptx", ".doc", ".docx", ".xls", ".xlsx", ".odp", ".odt");
	private static final Set<String> PDF_DIRECT_EXTS = Set.of(".pdf");

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

			// 转码逻辑：Office 文件转为 PDF，原生 PDF/图片直接用原链接
			String extLower = extension.toLowerCase();
			if (OFFICE_EXTS.contains(extLower)) {
				try {
					File pdfFile = convertToPdf(targetPath.toFile(), usageDir.toFile());
					metadata.setPdfUrl("/api/v1/common/static/" + pdfFile.getName() + "?usage=" + usage.name());
				} catch (Exception e) {
					logger.warning("Office 转 PDF 失败，跳过转码: " + e.getMessage());
					// 转码失败不影响上传，pdfUrl 留空
				}
			} else if (PDF_DIRECT_EXTS.contains(extLower)) {
				// 原生 PDF 直接赋值预览链接
				metadata.setPdfUrl("/api/v1/common/static/" + storedName + "?usage=" + usage.name());
			}

			return fileMetadataRepository.save(metadata);
		} catch (IOException ex) {
			throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "文件保存失败");
		}
	}

	/**
	 * 使用 LibreOffice 将 Office 文件转码为 PDF
	 */
	private File convertToPdf(File sourceFile, File outputDir) throws IOException, InterruptedException {
		// 兼容 Linux/Docker（libreoffice）和 macOS（soffice）
		String libreOfficeBin = resolveLibreOfficeBin();
		ProcessBuilder pb = new ProcessBuilder(
				libreOfficeBin, "--headless", "--convert-to", "pdf",
				sourceFile.getAbsolutePath(), "--outdir", outputDir.getAbsolutePath()
		);
		pb.redirectErrorStream(true);
		Process process = pb.start();
		int exitCode = process.waitFor();
		if (exitCode != 0) {
			throw new IOException("LibreOffice 转码失败，exit code: " + exitCode);
		}
		// 转码生成的 PDF 文件名与源文件同名但扩展名为 .pdf
		String pdfName = sourceFile.getName().replaceAll("\\.[^.]+$", "") + ".pdf";
		File pdfFile = new File(outputDir, pdfName);
		if (!pdfFile.exists()) {
			throw new IOException("转码后 PDF 文件未找到: " + pdfFile.getAbsolutePath());
		}
		return pdfFile;
	}

	private String resolveLibreOfficeBin() {
		// macOS
		String macos = "/Applications/LibreOffice.app/Contents/MacOS/soffice";
		if (new File(macos).exists()) return macos;
		// Linux / Docker
		return "libreoffice";
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
