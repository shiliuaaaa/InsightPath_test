package com.example.demo.auth.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * 发送验证码请求
 */
public class SendSmsRequest {
	
	@NotBlank(message = "手机号不能为空")
	private String phone;
	
	@NotBlank(message = "用途不能为空")
	private String type;  // LOGIN 或 REGISTER
	
	public SendSmsRequest() {
	}
	
	public SendSmsRequest(String phone, String type) {
		this.phone = phone;
		this.type = type;
	}
	
	public String getPhone() {
		return phone;
	}
	
	public void setPhone(String phone) {
		this.phone = phone;
	}
	
	public String getType() {
		return type;
	}
	
	public void setType(String type) {
		this.type = type;
	}
}

