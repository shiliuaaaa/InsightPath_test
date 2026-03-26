package com.example.demo.common.dto;

import com.example.demo.common.entity.FileUsage;

public class FileUploadResponse {

	private String filename;
	private String url;
	private long size;
	private FileUsage usage;
	private String pdfUrl;
	private Long courseFileId;

	public FileUploadResponse(String filename, String url, long size, FileUsage usage) {
		this.filename = filename;
		this.url = url;
		this.size = size;
		this.usage = usage;
	}

	public Long getCourseFileId() {
		return courseFileId;
	}

	public void setCourseFileId(Long courseFileId) {
		this.courseFileId = courseFileId;
	}

	public String getPdfUrl() {
		return pdfUrl;
	}

	public void setPdfUrl(String pdfUrl) {
		this.pdfUrl = pdfUrl;
	}

	public String getFilename() {
		return filename;
	}

	public void setFilename(String filename) {
		this.filename = filename;
	}

	public String getUrl() {
		return url;
	}

	public void setUrl(String url) {
		this.url = url;
	}

	public long getSize() {
		return size;
	}

	public void setSize(long size) {
		this.size = size;
	}

	public FileUsage getUsage() {
		return usage;
	}

	public void setUsage(FileUsage usage) {
		this.usage = usage;
	}
}
