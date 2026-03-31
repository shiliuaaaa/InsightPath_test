package com.example.demo.auth.service;

import com.example.demo.auth.dto.LoginRequest;
import com.example.demo.auth.dto.LoginResponse;
import com.example.demo.auth.dto.LoginSmsRequest;
import com.example.demo.auth.dto.RegisterRequest;
import com.example.demo.auth.dto.RegisterResponse;
import com.example.demo.auth.dto.UserInfo;
import com.example.demo.auth.entity.Role;
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
	private final SmsService smsService;
	private final RsaKeyService rsaKeyService;

	public UserService(UserRepository userRepository, PasswordEncoder passwordEncoder, JwtService jwtService, SmsService smsService, RsaKeyService rsaKeyService) {
		this.userRepository = userRepository;
		this.passwordEncoder = passwordEncoder;
		this.jwtService = jwtService;
		this.smsService = smsService;
		this.rsaKeyService = rsaKeyService;
	}

	public RegisterResponse register(RegisterRequest request) {
		// 1. 验证验证码
		smsService.verifyCode(request.getPhone(), request.getSmsCode());
		
		// 2. 校验唯一性
		if (userRepository.existsByUsername(request.getUsername())) {
			throw new ResponseStatusException(HttpStatus.CONFLICT, "该账号名已被注册");
		}
		if (userRepository.existsByPhoneAndRole(request.getPhone(), request.getRole())) {
			throw new ResponseStatusException(HttpStatus.CONFLICT, "该手机号对应角色已被注册");
		}

		// 3. 解密密码
		String decryptedPassword = rsaKeyService.decryptPassword(request.getPassword());
		
		// 4. 密码校验
		validatePasswordRule(decryptedPassword);

		// 5. 创建用户
		User user = new User();
		user.setUsername(request.getUsername());
		user.setPhone(request.getPhone());
		user.setRole(request.getRole());
		user.setNickname(request.getNickname() != null && !request.getNickname().isBlank()
				? request.getNickname()
				: request.getUsername());
		user.setPasswordHash(passwordEncoder.encode(decryptedPassword));

		User saved = userRepository.save(user);
		return new RegisterResponse(saved.getId(), "注册成功，请登录");
	}

	public LoginResponse login(LoginRequest request) {
		User user = userRepository.findByUsername(request.getUsername())
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "账号或密码错误"));

		// 解密客户端发送的加密密码
		String decryptedPassword = rsaKeyService.decryptPassword(request.getPassword());
		
		if (!passwordEncoder.matches(decryptedPassword, user.getPasswordHash())) {
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

	/**
	 * 手机号 + 验证码登录
	 */
	public LoginResponse loginWithSms(LoginSmsRequest request) {
		// 1. 验证验证码
		smsService.verifyCode(request.getPhone(), request.getCode());
		
		// 2. 查找或创建用户
		Role role = Role.valueOf(request.getRole());
		User user = userRepository.findByPhoneAndRole(request.getPhone(), role)
				.orElseGet(() -> createUserFromPhone(request.getPhone(), role));
		
		// 3. 生成 Token
		String token = jwtService.generateToken(user, request.getDeviceId());
		
		// 4. 构建用户信息
		UserInfo userInfo = new UserInfo();
		userInfo.setId(user.getId());
		userInfo.setUsername(user.getUsername());
		userInfo.setNickname(user.getNickname());
		userInfo.setRole(user.getRole());
		userInfo.setAvatar(user.getAvatarUrl());
		userInfo.setSchoolId(user.getSchoolId());
		userInfo.setVerified(false);
		
		return new LoginResponse(token, userInfo);
	}
	
	/**
	 * 从手机号创建新用户
	 */
	private User createUserFromPhone(String phone, Role role) {
		User user = new User();
		user.setPhone(phone);
		user.setRole(role);
		
		// 生成唯一的用户名
		String username = generateUsernameFromPhone(phone, role);
		user.setUsername(username);
		
		// 设置昵称为手机号后4位
		user.setNickname("用户" + phone.substring(7));
		
		// 设置临时密码（用户可以后续修改）
		user.setPasswordHash(passwordEncoder.encode("123456"));
		
		return userRepository.save(user);
	}
	
	/**
	 * 从手机号生成唯一用户名
	 */
	private String generateUsernameFromPhone(String phone, Role role) {
		String rolePrefix = role == Role.STUDENT ? "stu" : "tea";
		String username = rolePrefix + "_" + phone.substring(7);
		
		// 如果用户名已存在，添加随机后缀
		int counter = 1;
		String originalUsername = username;
		while (userRepository.existsByUsername(username)) {
			username = originalUsername + "_" + counter;
			counter++;
		}
		
		return username;
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
