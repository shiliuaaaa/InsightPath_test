package com.example.demo.auth.controller;

import com.example.demo.auth.dto.LoginResponse;
import com.example.demo.auth.dto.UserInfo;
import com.example.demo.auth.entity.User;
import com.example.demo.auth.filter.JwtAuthFilter;
import com.example.demo.auth.repository.UserRepository;
import com.example.demo.auth.service.JwtService;
import com.example.demo.common.entity.School;
import com.example.demo.common.repository.SchoolRepository;
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
	private final SchoolRepository schoolRepository;

	public UsersController(JwtService jwtService, UserRepository userRepository, SchoolRepository schoolRepository) {
		this.jwtService = jwtService;
		this.userRepository = userRepository;
		this.schoolRepository = schoolRepository;
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
		userInfo.setBgUrl(user.getBgUrl());
		userInfo.setBio(user.getBio());
		userInfo.setSchoolId(user.getSchoolId());
		if (user.getSchoolId() != null) {
			schoolRepository.findById(user.getSchoolId()).map(School::getName).ifPresent(userInfo::setSchool);
		}
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
		return updateUserById(userId, body);
	}

	@PutMapping("/{id}")
	public ApiResponse<UpdateUserResponse> updateById(@PathVariable("id") Long id,
										@RequestBody UpdateUserRequest body,
										HttpServletRequest request) {
		Claims claims = (Claims) request.getAttribute(JwtAuthFilter.CLAIMS_ATTRIBUTE);
		if (claims == null) {
			throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "未登录");
		}
		Long loginUserId = extractUserId(claims.get("user_id"));
		if (loginUserId == null) {
			throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "未登录");
		}
		if (!loginUserId.equals(id)) {
			throw new ResponseStatusException(HttpStatus.FORBIDDEN, "无权限修改该用户信息");
		}
		return updateUserById(id, body);
	}

	private ApiResponse<UpdateUserResponse> updateUserById(Long userId, UpdateUserRequest body) {
		User user = userRepository.findById(userId)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "用户不存在"));

		if (body.getNickname() != null && !body.getNickname().isBlank()) {
			user.setNickname(body.getNickname());
		}
		if (body.getSchoolId() != null) {
			user.setSchoolId(body.getSchoolId());
		} else if (body.getSchool() != null) {
			String schoolName = body.getSchool().trim();
			if (schoolName.isEmpty()) {
				user.setSchoolId(null);
			} else {
				School school = schoolRepository.findByName(schoolName);
				if (school == null) {
					school = new School();
					school.setName(schoolName);
					school = schoolRepository.save(school);
				}
				user.setSchoolId(school.getId());
			}
		}
		if (body.getAvatarUrl() != null) {
			user.setAvatarUrl(body.getAvatarUrl().isBlank() ? null : body.getAvatarUrl());
		}
		if (body.getBgUrl() != null) {
			user.setBgUrl(body.getBgUrl().isBlank() ? null : body.getBgUrl());
		}
		if (body.getBio() != null) {
			user.setBio(body.getBio().isBlank() ? null : body.getBio());
		}
		user.setUpdatedAt(java.time.LocalDateTime.now());
		userRepository.save(user);

		UpdateUserResponse resp = new UpdateUserResponse();
		resp.setId(user.getId());
		resp.setNickname(user.getNickname());
		resp.setSchoolId(user.getSchoolId());
		if (user.getSchoolId() != null) {
			schoolRepository.findById(user.getSchoolId()).map(School::getName).ifPresent(resp::setSchool);
		}
		resp.setAvatarUrl(user.getAvatarUrl());
		resp.setBgUrl(user.getBgUrl());
		resp.setBio(user.getBio());
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