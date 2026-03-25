package com.example.demo.auth.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * 手机号 + 验证码登录请求
 */
public class LoginSmsRequest {
	
	@NotBlank(message = "手机号不能为空")
	private String phone;
	
	@NotBlank(message = "验证码不能为空")
	private String code;
	
	@NotBlank(message = "角色不能为空")
	private String role;  // STUDENT 或 TEACHER
	
	@NotBlank(message = "设备ID不能为空")
	private String deviceId;
	
	public LoginSmsRequest() {
	}
	
	public LoginSmsRequest(String phone, String code, String role, String deviceId) {
		this.phone = phone;
		this.code = code;
		this.role = role;
		this.deviceId = deviceId;
	}
	
	public String getPhone() {
		return phone;
	}
	
	public void setPhone(String phone) {
		this.phone = phone;
	}
	
	public String getCode() {
		return code;
	}
	
	public void setCode(String code) {
		this.code = code;
	}
	
	public String getRole() {
		return role;
	}
	
	public void setRole(String role) {
		this.role = role;
	}
	
	public String getDeviceId() {
		return deviceId;
	}
	
	public void setDeviceId(String deviceId) {
		this.deviceId = deviceId;
	}
}

