package com.example.demo.auth.dto;

/**
 * 注册响应载体
 */
public class RegisterResponse {

	private Long userId;

	private String message;

	public RegisterResponse() {
	}

	public RegisterResponse(Long userId, String message) {
		this.userId = userId;
		this.message = message;
	}

	public Long getUserId() {
		return userId;
	}

	public void setUserId(Long userId) {
		this.userId = userId;
	}

	public String getMessage() {
		return message;
	}

	public void setMessage(String message) {
		this.message = message;
	}
}
