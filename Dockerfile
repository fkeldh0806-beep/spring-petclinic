# 사용할 자바 기본 이미지를 지정합니다. Spring Boot 애플리케이션에 적합합니다.
FFROM mcr.microsoft.com/openjdk/jdk:17-ubuntu as builder


# 환경 변수 설정
ENV SPRING_PROFILES_ACTIVE=mysql \
    RDS_HOSTNAME=localhost \
    RDS_PORT=3306 \
    RDS_DB_NAME=petclinic \
    RDS_USERNAME=pc_owner \
    RDS_PASSWORD=pc_password

# 작업 디렉토리 설정
WORKDIR /app

# Maven 빌드 및 실행을 위해 Maven wrapper를 복사합니다.
COPY .mvn .mvn
COPY mvnw pom.xml ./

# 의존성 다운로드 (캐싱을 위해 먼저 실행)
RUN ./mvnw dependency:go-offline

# 소스 코드 복사 및 빌드
COPY src src

# 빌드 실행
RUN ./mvnw package -DskipTests

# -----------------
# 실행 단계 (Jib 빌드가 아니므로 명시적 실행 환경 필요)
FROM mcr.microsoft.com/openjdk/jdk:17-ubuntu
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
