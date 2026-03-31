package com.example.demo.auth.filter;

import com.example.demo.auth.service.JwtService;
import io.jsonwebtoken.Claims;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpStatus;
import org.springframework.lang.NonNull;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;

public class JwtAuthFilter extends OncePerRequestFilter {

	public static final String CLAIMS_ATTRIBUTE = "jwtClaims";

	private final JwtService jwtService;
	private final List<String> excludedPaths;

	public JwtAuthFilter(JwtService jwtService, List<String> excludedPaths) {
		this.jwtService = jwtService;
		this.excludedPaths = excludedPaths;
	}

	@Override
	protected void doFilterInternal(@NonNull HttpServletRequest request,
									@NonNull HttpServletResponse response,
									@NonNull FilterChain filterChain)
			throws ServletException, IOException {
		String authorization = request.getHeader("Authorization");

		// 如果没有 Token
		if (authorization == null || authorization.isBlank()) {
			String path = request.getRequestURI();
			// 如果是排除路径，允许匿名访问 (user=null)
			if (excludedPaths.stream().anyMatch(path::startsWith)) {
				filterChain.doFilter(request, response);
				return;
			}
			// 否则 401
			response.sendError(HttpStatus.UNAUTHORIZED.value(), "缺少有效的Authorization头");
			return;
		}

		// 如果有 Token，尝试解析
		try {
			String token = jwtService.extractBearerToken(authorization);
			Claims claims = jwtService.parseToken(token);
			request.setAttribute(CLAIMS_ATTRIBUTE, claims);
			filterChain.doFilter(request, response);
		} catch (Exception ex) {
			response.sendError(HttpStatus.UNAUTHORIZED.value(), "Token无效或已过期");
		}
	}
}