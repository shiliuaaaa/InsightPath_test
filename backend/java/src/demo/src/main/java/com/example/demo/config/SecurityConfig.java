package com.example.demo.config;

import com.example.demo.auth.filter.JwtAuthFilter;
import com.example.demo.auth.service.JwtService;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.List;

@Configuration
public class SecurityConfig {

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public FilterRegistrationBean<JwtAuthFilter> jwtAuthFilter(JwtService jwtService) {
        FilterRegistrationBean<JwtAuthFilter> registration = new FilterRegistrationBean<>();
        registration.setFilter(new JwtAuthFilter(jwtService, List.of(
                "/api/v1/auth/register",
                "/api/v1/auth/login/password",
                "/api/v1/auth/sms/send",
                "/api/v1/auth/login/sms",
                "/api/v1/auth/public-key",
                "/api/v1/common/file/access",
                "/api/v1/common/schools",
                "/api/v1/courses", // 允许未登录查看课程列表
                "/health"          // 健康检查接口
        )));
        registration.setOrder(1);
        return registration;
    }
}