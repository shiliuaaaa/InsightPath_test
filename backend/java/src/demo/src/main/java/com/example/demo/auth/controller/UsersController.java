package com.example.demo.auth.controller;

import com.example.demo.auth.dto.LoginResponse;
import com.example.demo.auth.dto.UserInfo;
import com.example.demo.auth.entity.User;
import com.example.demo.auth.filter.JwtAuthFilter;
import com.example.demo.auth.repository.UserRepository;
import com.example.demo.auth.service.JwtService;
import com.example.demo.course.dto.UpdateUserRequest;
import com.example.demo.course.dto.UpdateUserResponse;
import com.example.demo.dto.ApiResponse;
import io.jsonwebtoken.Claims;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/v1/users")
public class UsersController {

	private final JwtService jwtService;
	private final UserRepository userRepository;

	public UsersController(JwtService jwtService, UserRepository userRepository) {
		this.jwtService = jwtService;
		this.userRepository = userRepository;
	}

	@GetMapping("/me")
	public ApiResponse<LoginResponse> me(@RequestHeader("Authorization") String authorization,
									HttpServletRequest request) {
		String token = jwtService.extractBearerToken(authorization);
		Claims claims = (Claims) request.getAttribute(JwtAuthFilter.CLAIMS_ATTRIBUTE);
		if (claims == null) {
			throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "账号或密码错误");
		}

		Long userId = extractUserId(claims.get("user_id"));
		if (userId == null) {
			throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "账号或密码错误");
		}
		User user = userRepository.findById(userId)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "账号或密码错误"));

		UserInfo userInfo = new UserInfo();
		userInfo.setId(user.getId());
		userInfo.setUsername(user.getUsername());
		userInfo.setNickname(user.getNickname());
		userInfo.setRole(user.getRole());
		userInfo.setAvatar(user.getAvatarUrl());
		userInfo.setSchoolId(user.getSchoolId());
		userInfo.setVerified(false);

		return ApiResponse.success("登录成功", new LoginResponse(token, userInfo));
	}

	@PutMapping("/me")
	public ApiResponse<UpdateUserResponse> updateMe(@RequestBody UpdateUserRequest body,
									HttpServletRequest request) {
		Claims claims = (Claims) request.getAttribute(JwtAuthFilter.CLAIMS_ATTRIBUTE);
		if (claims == null) {
			throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "未登录");
		}
		Long userId = extractUserId(claims.get("user_id"));
		if (userId == null) {
			throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "未登录");
		}
		User user = userRepository.findById(userId)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "用户不存在"));

		if (body.getNickname() != null && !body.getNickname().isBlank()) {
			user.setNickname(body.getNickname());
		}
		if (body.getSchoolId() != null) {
			user.setSchoolId(body.getSchoolId());
		}
		user.setUpdatedAt(java.time.LocalDateTime.now());
		userRepository.save(user);

		UpdateUserResponse resp = new UpdateUserResponse();
		resp.setId(user.getId());
		resp.setNickname(user.getNickname());
		resp.setSchoolId(user.getSchoolId());
		resp.setRole(user.getRole().name());
		resp.setUpdatedAt(user.getUpdatedAt());

		return ApiResponse.success("更新成功", resp);
	}

	private Long extractUserId(Object rawUserId) {
		if (rawUserId instanceof Number number) {
			return number.longValue();
		}
		if (rawUserId instanceof String text) {
			try {
				return Long.parseLong(text);
			} catch (NumberFormatException ex) {
				throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "账号或密码错误");
			}
		}
		throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "账号或密码错误");
	}
}