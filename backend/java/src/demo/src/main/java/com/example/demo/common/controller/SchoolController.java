package com.example.demo.common.controller;

import com.example.demo.common.entity.School;
import com.example.demo.common.repository.SchoolRepository;
import com.example.demo.dto.ApiResponse;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * 学校管理控制器
 * 提供学校列表查询和搜索功能
 */
@RestController
@RequestMapping("/api/v1/common/schools")
public class SchoolController {

	private final SchoolRepository schoolRepository;

	public SchoolController(SchoolRepository schoolRepository) {
		this.schoolRepository = schoolRepository;
	}

	/**
	 * 获取学校列表
	 * 支持关键词模糊搜索
	 * 
	 * @param keyword 搜索关键词（可选）
	 * @return 学校列表
	 * 
	 * 示例：
	 * GET /api/v1/common/schools           - 获取所有学校
	 * GET /api/v1/common/schools?keyword=清华  - 搜索包含"清华"的学校
	 */
	@GetMapping
	public ApiResponse<List<School>> listSchools(
			@RequestParam(required = false) String keyword) {
		
		List<School> schools;
		
		if (StringUtils.hasText(keyword)) {
			// 有关键词：模糊搜索
			schools = schoolRepository.findByNameContaining(keyword);
		} else {
			// 无关键词：返回全部学校
			schools = schoolRepository.findAll();
		}
		
		return ApiResponse.success("获取成功", schools);
	}
}

