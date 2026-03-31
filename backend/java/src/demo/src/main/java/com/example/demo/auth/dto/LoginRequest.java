package com.example.demo.auth.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public class LoginRequest {

	@NotBlank(message = "用户名不能为空")
	@Size(min = 4, max = 32, message = "用户名长度需在4-32个字符")
	private String username;

	@NotBlank(message = "密码不能为空")
	// 密码在客户端已 RSA 加密，此处接收密文，不对密文做长度校验
	private String password;

	
	@JsonProperty("device_id")
	@NotBlank(message = "设备ID不能为空")
	private String deviceId;

	public String getUsername() {
		return username;
	}

	public void setUsername(String username) {
		this.username = username;
	}

	public String getPassword() {
		return password;
	}

	public void setPassword(String password) {
		this.password = password;
	}

	public String getDeviceId() {
		return deviceId;
	}

	public void setDeviceId(String deviceId) {
		this.deviceId = deviceId;
	}
}
