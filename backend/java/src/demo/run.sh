#!/bin/bash

# 设置 Java 17
export JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.18/libexec/openjdk.jdk/Contents/Home
export PATH="$JAVA_HOME/bin:$PATH"

echo "✅ Java 版本:"
java -version

echo ""
echo "🚀 启动 Spring Boot 应用..."
./mvnw spring-boot:run

