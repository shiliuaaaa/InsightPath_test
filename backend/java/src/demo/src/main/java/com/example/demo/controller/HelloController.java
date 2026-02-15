package com.example.demo.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

@RestController
public class HelloController {

    /**
     * 一个基本的 GET 请求接口
     * 访问地址: http://localhost:8080/hello?name=Zhang
     */
    @GetMapping("/hello")
    public Map<String, Object> sayHello(@RequestParam(name = "name", defaultValue = "World") String name) {
        // 创建一个 Map 对象作为返回数据，Spring Boot 会自动将其转换为 JSON 格式
        Map<String, Object> response = new HashMap<>();
        response.put("message", "Hello, " + name + "!");
        response.put("time", LocalDateTime.now());
        response.put("status", "success");
        
        return response;
    }
}
