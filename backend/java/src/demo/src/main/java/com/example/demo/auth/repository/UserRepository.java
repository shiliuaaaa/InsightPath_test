package com.example.demo.auth.repository;

import com.example.demo.auth.entity.Role;
import com.example.demo.auth.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {

	Optional<User> findByUsername(String username);

	Optional<User> findByPhone(String phone);

	Optional<User> findByPhoneAndRole(String phone, Role role);

	boolean existsByUsername(String username);

	boolean existsByPhoneAndRole(String phone, Role role);

	List<User> findByNicknameContainingOrUsernameContaining(String nickname, String username);
}
