package com.example.demo.auth.controller;

import com.example.demo.auth.dto.LoginRequest;
import com.example.demo.auth.dto.LoginResponse;
import com.example.demo.auth.dto.LoginSmsRequest;
import com.example.demo.auth.dto.PublicKeyResponse;
import com.example.demo.auth.dto.RegisterRequest;
import com.example.demo.auth.dto.RegisterResponse;
import com.example.demo.auth.dto.SendSmsRequest;
import com.example.demo.auth.service.JwtService;
import com.example.demo.auth.service.RsaKeyService;
import com.example.demo.auth.service.SmsService;
import com.example.demo.auth.service.UserService;
import com.example.demo.dto.ApiResponse;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

	private final UserService userService;
	private final JwtService jwtService;
	private final SmsService smsService;
	private final RsaKeyService rsaKeyService;

	public AuthController(UserService userService, JwtService jwtService, SmsService smsService, RsaKeyService rsaKeyService) {
		this.userService = userService;
		this.jwtService = jwtService;
		this.smsService = smsService;
		this.rsaKeyService = rsaKeyService;
	}

	/**
	 * 获取 RSA 公钥
	 * GET /api/v1/auth/public-key
	 * 
	 * 客户端在登录或注册前调用此接口获取公钥，用于加密密码
	 */
	@GetMapping("/public-key")
	public ApiResponse<PublicKeyResponse> getPublicKey() {
		String publicKeyBase64 = rsaKeyService.getPublicKeyBase64();
		return ApiResponse.success("获取成功", new PublicKeyResponse(publicKeyBase64));
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

	@PostMapping("/logout")
	public ApiResponse<Void> logout(@RequestHeader("Authorization") String authorization) {
		String token = jwtService.extractBearerToken(authorization);
		try {
			jwtService.parseToken(token);
		} catch (Exception ex) {
			throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Token无效或已过期");
		}
		return ApiResponse.success("退出成功", null);
	}

	/**
	 * 发送短信验证码
	 * POST /api/v1/auth/sms/send
	 * 
	 * 开发环境：模拟发送，验证码直接返回到 data.code 字段（供前端弹窗展示）
	 * 生产环境：调用真实短信服务，data 为 null
	 */
	@PostMapping("/sms/send")
	public ApiResponse<java.util.Map<String, String>> sendSms(@Valid @RequestBody SendSmsRequest request) {
		smsService.sendVerificationCode(request.getPhone(), request.getType());
		// 开发 mock 模式下把验证码带回，方便演示
		String mockCode = smsService.getCodeForTesting(request.getPhone());
		if (mockCode != null) {
			return ApiResponse.success("验证码发送成功", java.util.Map.of("code", mockCode));
		}
		return ApiResponse.success("验证码发送成功", null);
	}

	/**
	 * 手机号 + 验证码登录
	 * POST /api/v1/auth/login/sms
	 */
	@PostMapping("/login/sms")
	public ApiResponse<LoginResponse> loginWithSms(@Valid @RequestBody LoginSmsRequest request) {
		LoginResponse response = userService.loginWithSms(request);
		return ApiResponse.success("登录成功", response);
	}
}
