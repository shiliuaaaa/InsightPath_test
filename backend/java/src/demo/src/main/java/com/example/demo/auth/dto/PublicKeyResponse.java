package com.example.demo.auth.dto;

/**
 * 公钥响应
 */
public class PublicKeyResponse {
	
	private String publicKey;
	
	public PublicKeyResponse(String publicKey) {
		this.publicKey = publicKey;
	}
	
	public String getPublicKey() {
		return publicKey;
	}
	
	public void setPublicKey(String publicKey) {
		this.publicKey = publicKey;
	}
}

