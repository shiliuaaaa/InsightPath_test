package com.example.demo.auth.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.util.Random;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.logging.Logger;

/**
 * SMS 验证码服务
 * 开发环境：模拟验证码，直接打印到日志
 * 生产环境：可切换为真实短信服务（阿里云、腾讯云等）
 */
@Service
public class SmsService {

	private static final Logger logger = Logger.getLogger(SmsService.class.getName());
	
	// 验证码信息类
	private static class CodeInfo {
		String code;
		long expirationTime;
		
		CodeInfo(String code, long expirationTime) {
			this.code = code;
			this.expirationTime = expirationTime;
		}
	}
	
	// 验证码缓存：phone -> CodeInfo
	private final ConcurrentHashMap<String, CodeInfo> codeCache = new ConcurrentHashMap<>();
	
	// 验证码有效期（分钟）
	private static final int CODE_EXPIRATION_MINUTES = 5;
	
	// 验证码长度
	private static final int CODE_LENGTH = 6;
	
	@Value("${app.sms.mode:mock}")
	private String smsMode;  // mock 或 real
	
	private final ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(1);
	
	public SmsService() {
		// 定期清理过期验证码
		scheduler.scheduleAtFixedRate(this::cleanupExpiredCodes, 1, 1, TimeUnit.MINUTES);
	}
	
	/**
	 * 发送验证码
	 * @param phone 手机号
	 * @param type 用途：LOGIN 或 REGISTER
	 */
	public void sendVerificationCode(String phone, String type) {
		// 验证手机号格式
		if (!isValidPhone(phone)) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "手机号格式不正确");
		}
		
		// 生成 6 位随机验证码
		String code = generateCode();
		
		// 计算过期时间
		long expirationTime = System.currentTimeMillis() + (CODE_EXPIRATION_MINUTES * 60 * 1000);
		
		// 存储到缓存
		codeCache.put(phone, new CodeInfo(code, expirationTime));
		
		// 根据模式选择发送方式
		if ("real".equals(smsMode)) {
			// 生产环境：调用真实短信服务
			sendRealSms(phone, code, type);
		} else {
			// 开发环境：模拟发送（打印到日志和控制台）
			sendMockSms(phone, code, type);
		}
	}
	
	/**
	 * 验证验证码
	 * @param phone 手机号
	 * @param code 用户输入的验证码
	 * @return 验证是否成功
	 */
	public boolean verifyCode(String phone, String code) {
		CodeInfo codeInfo = codeCache.get(phone);
		
		if (codeInfo == null) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "验证码已过期，请重新获取");
		}
		
		// 检查是否过期
		if (System.currentTimeMillis() > codeInfo.expirationTime) {
			codeCache.remove(phone);
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "验证码已过期，请重新获取");
		}
		
		if (!codeInfo.code.equals(code)) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "验证码错误");
		}
		
		// 验证成功后删除验证码
		codeCache.remove(phone);
		return true;
	}
	
	/**
	 * 生成 6 位随机验证码
	 */
	private String generateCode() {
		Random random = new Random();
		StringBuilder code = new StringBuilder();
		for (int i = 0; i < CODE_LENGTH; i++) {
			code.append(random.nextInt(10));
		}
		return code.toString();
	}
	
	/**
	 * 验证手机号格式
	 */
	private boolean isValidPhone(String phone) {
		// 简单的手机号验证（11位数字）
		return phone != null && phone.matches("^1[3-9]\\d{9}$");
	}
	
	/**
	 * 模拟发送短信（开发环境）
	 */
	private void sendMockSms(String phone, String code, String type) {
		String typeDesc = "LOGIN".equals(type) ? "登录" : "注册";
		
		// 打印到日志
		logger.info("=".repeat(50));
		logger.info("📱 模拟短信发送");
		logger.info("手机号: " + maskPhone(phone));
		logger.info("用途: " + typeDesc);
		logger.info("验证码: " + code);
		logger.info("有效期: " + CODE_EXPIRATION_MINUTES + " 分钟");
		logger.info("=".repeat(50));
		
		// 同时打印到控制台（便于开发者看到）
		System.out.println("\n" + "=".repeat(50));
		System.out.println("📱 模拟短信发送");
		System.out.println("手机号: " + maskPhone(phone));
		System.out.println("用途: " + typeDesc);
		System.out.println("✅ 验证码: " + code);
		System.out.println("有效期: " + CODE_EXPIRATION_MINUTES + " 分钟");
		System.out.println("=".repeat(50) + "\n");
	}
	
	/**
	 * 真实发送短信（生产环境）
	 * 这里只是占位符，实际需要集成阿里云、腾讯云等服务
	 */
	private void sendRealSms(String phone, String code, String type) {
		// TODO: 集成真实短信服务
		// 示例：阿里云短信
		// AliyunSmsClient.sendSms(phone, code);
		
		logger.info("发送真实短信到: " + phone + "，验证码: " + code);
	}
	
	/**
	 * 清理过期验证码
	 */
	private void cleanupExpiredCodes() {
		long now = System.currentTimeMillis();
		codeCache.entrySet().removeIf(entry -> entry.getValue().expirationTime < now);
	}
	
	/**
	 * 隐藏手机号中间部分（隐私保护）
	 */
	private String maskPhone(String phone) {
		if (phone == null || phone.length() < 7) {
			return phone;
		}
		return phone.substring(0, 3) + "****" + phone.substring(7);
	}
	
	/**
	 * 获取验证码（仅用于测试）
	 * 生产环境应该删除这个方法
	 */
	public String getCodeForTesting(String phone) {
		CodeInfo codeInfo = codeCache.get(phone);
		return codeInfo != null ? codeInfo.code : null;
	}
}

