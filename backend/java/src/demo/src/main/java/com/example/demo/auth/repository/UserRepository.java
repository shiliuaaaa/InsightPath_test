package com.example.demo.auth.repository;

import com.example.demo.auth.entity.Role;
import com.example.demo.auth.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {

	Optional<User> findByUsername(String username);

	Optional<User> findByPhone(String phone);

	boolean existsByUsername(String username);

	boolean existsByPhoneAndRole(String phone, Role role);
}
