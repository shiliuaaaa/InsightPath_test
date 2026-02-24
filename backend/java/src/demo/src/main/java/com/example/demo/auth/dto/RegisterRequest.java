package com.example.demo.auth.dto;

import com.example.demo.auth.entity.Role;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * 注册请求参数
 */
public class RegisterRequest {

	@NotBlank(message = "用户名不能为空")
	@Size(min = 4, max = 32, message = "用户名长度需在4-32个字符")
	@Pattern(regexp = "^[a-zA-Z0-9]+$", message = "用户名仅支持字母和数字")
	private String username;

	@NotBlank(message = "密码不能为空")
	@Size(min = 4, max = 32, message = "密码长度需在4-32个字符")
	@Pattern(regexp = "^[a-zA-Z0-9]+$", message = "密码仅支持字母和数字")
	private String password;

	@NotBlank(message = "手机号不能为空")
	@Pattern(regexp = "^1[3-9]\\d{9}$", message = "手机号格式不正确")
	private String phone;

	@Size(max = 32, message = "昵称长度不能超过32个字符")
	private String nickname;

	@NotNull(message = "角色不能为空")
	private Role role;

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

	public String getPhone() {
		return phone;
	}

	public void setPhone(String phone) {
		this.phone = phone;
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
}
