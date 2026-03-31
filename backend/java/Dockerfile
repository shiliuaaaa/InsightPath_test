# Build stage
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app


########################################
# 第一部分 源码编译
########################################
# 1. 缓存依赖
# 解决依赖的问题, 避免反复下载依赖
COPY src/demo/pom.xml .
RUN mvn dependency:go-offline -B

# 2. 编译源码
# 依赖下好了，再把源代码拷进去
COPY src/demo/src ./src
RUN mvn clean package -DskipTests

########################################
# 第二部分 运行Java
########################################

# Run stage
FROM eclipse-temurin:17-jre-jammy
WORKDIR /app

# 安装 LibreOffice 及中文字体（用于 Office 课件转码为 PDF）
RUN apt-get update && apt-get install -y --no-install-recommends \
    libreoffice \
    fonts-wqy-zenhei \
    fonts-wqy-microhei \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 1. 从上面的build阶段的结果中将运行结果直接拷贝进来
COPY --from=build /app/target/*.jar app.jar

# Expose the port the application runs on
EXPOSE 8080

# 2. 直接运行结果
ENTRYPOINT ["java", "-jar", "app.jar"]
