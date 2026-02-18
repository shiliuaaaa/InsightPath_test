package com.example.demo.auth.controller;

import com.example.demo.auth.dto.LoginRequest;
import com.example.demo.auth.dto.LoginResponse;
import com.example.demo.auth.dto.RegisterRequest;
import com.example.demo.auth.dto.RegisterResponse;
import com.example.demo.auth.service.UserService;
import com.example.demo.dto.ApiResponse;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

	private final UserService userService;

	public AuthController(UserService userService) {
		this.userService = userService;
	}

	@PostMapping("/register")
	public ApiResponse<RegisterResponse> register(@Valid @RequestBody RegisterRequest request) {
		RegisterResponse response = userService.register(request);
		return ApiResponse.success("注册成功，请登录", response);
	}

	@PostMapping("/login/password")
	public ApiResponse<LoginResponse> loginWithPassword(@Valid @RequestBody LoginRequest request) {
		LoginResponse response = userService.login(request);
		return ApiResponse.success("登录成功", response);
	}
}
