package com.example.demo.auth.service;

import org.springframework.stereotype.Service;

import javax.crypto.Cipher;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.PrivateKey;
import java.security.PublicKey;
import java.util.Base64;
import java.util.logging.Logger;

/**
 * RSA 密钥管理服务
 * 用于密码加密传输
 */
@Service
public class RsaKeyService {

	private static final Logger logger = Logger.getLogger(RsaKeyService.class.getName());
	
	private static final int KEY_SIZE = 2048;
	private static final String ALGORITHM = "RSA";
	
	private PublicKey publicKey;
	private PrivateKey privateKey;
	
	public RsaKeyService() {
		generateKeyPair();
	}
	
	/**
	 * 生成 RSA 密钥对
	 */
	private void generateKeyPair() {
		try {
			KeyPairGenerator keyGen = KeyPairGenerator.getInstance(ALGORITHM);
			keyGen.initialize(KEY_SIZE);
			KeyPair keyPair = keyGen.generateKeyPair();
			
			this.publicKey = keyPair.getPublic();
			this.privateKey = keyPair.getPrivate();
			
			logger.info("RSA 密钥对生成成功");
		} catch (Exception e) {
			logger.severe("RSA 密钥对生成失败: " + e.getMessage());
			throw new RuntimeException("RSA 密钥对生成失败", e);
		}
	}
	
	/**
	 * 获取公钥的 Base64 编码字符串
	 */
	public String getPublicKeyBase64() {
		return Base64.getEncoder().encodeToString(publicKey.getEncoded());
	}
	
	/**
	 * 使用私钥解密密码
	 * @param encryptedPassword Base64 编码的加密密码
	 * @return 解密后的明文密码
	 */
	public String decryptPassword(String encryptedPassword) {
		try {
			byte[] encryptedBytes = Base64.getDecoder().decode(encryptedPassword);
			Cipher cipher = Cipher.getInstance(ALGORITHM);
			cipher.init(Cipher.DECRYPT_MODE, privateKey);
			byte[] decryptedBytes = cipher.doFinal(encryptedBytes);
			return new String(decryptedBytes);
		} catch (Exception e) {
			logger.severe("密码解密失败: " + e.getMessage());
			throw new RuntimeException("密码解密失败", e);
		}
	}
	
	/**
	 * 获取公钥对象
	 */
	public PublicKey getPublicKey() {
		return publicKey;
	}
	
	/**
	 * 获取私钥对象
	 */
	public PrivateKey getPrivateKey() {
		return privateKey;
	}
}

