package com.example.demo.auth.service;

import com.example.demo.auth.dto.LoginRequest;
import com.example.demo.auth.dto.LoginResponse;
import com.example.demo.auth.dto.RegisterRequest;
import com.example.demo.auth.dto.RegisterResponse;
import com.example.demo.auth.dto.UserInfo;
import com.example.demo.auth.entity.User;
import com.example.demo.auth.repository.UserRepository;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

@Service
public class UserService {

	private final UserRepository userRepository;
	private final PasswordEncoder passwordEncoder;
	private final JwtService jwtService;

	public UserService(UserRepository userRepository, PasswordEncoder passwordEncoder, JwtService jwtService) {
		this.userRepository = userRepository;
		this.passwordEncoder = passwordEncoder;
		this.jwtService = jwtService;
	}

	public RegisterResponse register(RegisterRequest request) {
		// 校验唯一性
		if (userRepository.existsByUsername(request.getUsername())) {
			throw new ResponseStatusException(HttpStatus.CONFLICT, "该账号名已被注册");
		}
		if (userRepository.existsByPhoneAndRole(request.getPhone(), request.getRole())) {
			throw new ResponseStatusException(HttpStatus.CONFLICT, "该手机号对应角色已被注册");
		}

		// 密码校验
		validatePasswordRule(request.getPassword());

		User user = new User();
		user.setUsername(request.getUsername());
		user.setPhone(request.getPhone());
		user.setRole(request.getRole());
		user.setNickname(request.getNickname() != null && !request.getNickname().isBlank()
				? request.getNickname()
				: request.getUsername());
		user.setPasswordHash(passwordEncoder.encode(request.getPassword()));

		User saved = userRepository.save(user);
		return new RegisterResponse(saved.getId(), "注册成功，请登录");
	}

	public LoginResponse login(LoginRequest request) {
		User user = userRepository.findByUsername(request.getUsername())
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "账号或密码错误"));

		if (!passwordEncoder.matches(request.getPassword(), user.getPasswordHash())) {
			throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "账号或密码错误");
		}

		UserInfo userInfo = new UserInfo();
		userInfo.setId(user.getId());
		userInfo.setUsername(user.getUsername());
		userInfo.setNickname(user.getNickname());
		userInfo.setRole(user.getRole());
		userInfo.setAvatar(user.getAvatarUrl());
		userInfo.setSchoolId(user.getSchoolId());
		userInfo.setVerified(false);

		String token = jwtService.generateToken(user, request.getDeviceId());
		return new LoginResponse(token, userInfo);
	}

	private void validatePasswordRule(String password) {
		if (password == null || password.length() < 4 || password.length() > 32) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "密码长度需在4-32个字符");
		}
		if (!password.matches("^[a-zA-Z0-9]+$")) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "密码仅支持字母和数字");
		}
	}
}
