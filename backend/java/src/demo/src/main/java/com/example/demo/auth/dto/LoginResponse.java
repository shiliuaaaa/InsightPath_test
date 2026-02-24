package com.example.demo.auth.dto;

public class LoginResponse {

	private String token;

	private UserInfo userInfo;

	public LoginResponse() {
	}

	public LoginResponse(String token, UserInfo userInfo) {
		this.token = token;
		this.userInfo = userInfo;
	}

	public String getToken() {
		return token;
	}

	public void setToken(String token) {
		this.token = token;
	}

	public UserInfo getUserInfo() {
		return userInfo;
	}

	public void setUserInfo(UserInfo userInfo) {
		this.userInfo = userInfo;
	}
}
