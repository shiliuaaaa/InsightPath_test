package com.example.demo.common.repository;

import com.example.demo.common.entity.School;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface SchoolRepository extends JpaRepository<School, Long> {

    // 根据名称模糊搜索学校
    List<School> findByNameContaining(String keyword);

    // 根据名称精确查找
    School findByName(String name);
}

