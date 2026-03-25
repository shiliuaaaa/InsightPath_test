package com.example.demo.common.dto;

import com.example.demo.common.entity.FileUsage;
import com.fasterxml.jackson.annotation.JsonProperty;

public class FileAccessRequest {

	private String filename;
	private FileUsage usage;
	private Long id;

	@JsonProperty("section_id")
	private Long sectionId;

	public String getFilename() {
		return filename;
	}

	public void setFilename(String filename) {
		this.filename = filename;
	}

	public FileUsage getUsage() {
		return usage;
	}

	public void setUsage(FileUsage usage) {
		this.usage = usage;
	}

	public Long getId() {
		return id;
	}

	public void setId(Long id) {
		this.id = id;
	}

	public Long getSectionId() {
		return sectionId;
	}

	public void setSectionId(Long sectionId) {
		this.sectionId = sectionId;
	}
}
