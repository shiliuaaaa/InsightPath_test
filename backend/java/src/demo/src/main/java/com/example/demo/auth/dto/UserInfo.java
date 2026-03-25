package com.example.demo.auth.dto;

import com.example.demo.auth.entity.Role;
import com.fasterxml.jackson.annotation.JsonProperty;

public class UserInfo {

	private Long id;

	private String username;

	private String nickname;

	private Role role;

	private String avatar;

	@JsonProperty("school_id")
	private Long schoolId;

	@JsonProperty("is_verified")
	private boolean isVerified;

	public Long getId() {
		return id;
	}

	public void setId(Long id) {
		this.id = id;
	}

	public String getUsername() {
		return username;
	}

	public void setUsername(String username) {
		this.username = username;
	}

	public String getNickname() {
		return nickname;
	}

	public void setNickname(String nickname) {
		this.nickname = nickname;
	}

	public Role getRole() {
		return role;
	}

	public void setRole(Role role) {
		this.role = role;
	}

	public String getAvatar() {
		return avatar;
	}

	public void setAvatar(String avatar) {
		this.avatar = avatar;
	}

	public Long getSchoolId() {
		return schoolId;
	}

	public void setSchoolId(Long schoolId) {
		this.schoolId = schoolId;
	}

	public boolean isVerified() {
		return isVerified;
	}

	public void setVerified(boolean verified) {
		isVerified = verified;
	}
}
