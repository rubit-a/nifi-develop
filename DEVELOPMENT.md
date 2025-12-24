# NiFi Custom Processors - 개발 환경 가이드

## 📋 목차

- [시스템 요구사항](#시스템-요구사항)
- [프로젝트 구조](#프로젝트-구조)
- [빌드 환경](#빌드-환경)
- [개발 워크플로우](#개발-워크플로우)
- [스크립트 사용법](#스크립트-사용법)
- [트러블슈팅](#트러블슈팅)

---

## 시스템 요구사항

### 필수 요구사항

| 항목 | 요구사항 | 확인 방법 |
|------|----------|----------|
| **Docker** | Docker Desktop 설치 및 실행 | `docker --version` |
| **Git** | Git 설치 | `git --version` |

### 선택적 요구사항 (로컬 빌드 시)

| 항목 | 버전 | 용도 |
|------|------|------|
| **Java (JDK)** | 21 | 로컬 Maven 빌드 시 필요 |
| **Maven** | 3.9+ | 로컬 Maven 빌드 시 필요 |

> **권장사항**: Docker만 설치하면 Java/Maven 없이도 개발 가능합니다.

---

## 프로젝트 구조

```
nifi-deploy/
├── nifi-custom-processors/          # 커스텀 프로세서 소스 코드
│   ├── src/
│   │   ├── main/java/               # 프로세서 구현
│   │   └── test/java/               # 단위 테스트
│   └── pom.xml                      # Maven 설정
│
├── nifi-custom-nar/                 # NAR 패키징 모듈
│   ├── pom.xml
│   └── target/
│       └── nifi-custom-nar-1.0.0.nar  # 빌드 결과물
│
├── scripts/dev/                     # 개발 스크립트
│   ├── build-nar.sh                 # NAR 빌드 스크립트
│   ├── docker-nifi.sh               # NiFi 실행 관리
│   └── docker-compose.yml           # NiFi 컨테이너 설정
│
├── .m2-docker/                      # Docker Maven 캐시 (자동 생성)
├── pom.xml                          # 루트 Maven 설정
└── README.md                        # 프로젝트 소개
```

---

## 빌드 환경

### 1. Docker 기반 빌드 (권장)

Docker를 사용하면 로컬에 Java/Maven을 설치하지 않아도 됩니다.

#### 작동 원리

```
┌─────────────────────────────────────────────────────────┐
│ 1. Docker 컨테이너 생성                                    │
│    Image: maven:3.9-eclipse-temurin-21                  │
│    → Java 21 + Maven 3.9 포함                            │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│ 2. 프로젝트 디렉토리 마운트                                   │
│    Host: /Users/you/nifi-deploy                         │
│    Container: /workspace                                │
│    → 실시간 파일 동기화                                     │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│ 3. 컨테이너 안에서 빌드 실행                                  │
│    $ mvn clean test package                             │
│    → Java 소스 코드 컴파일                                  │
│    → 단위 테스트 실행                                       │
│    → .nar 파일 패키징                                      │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│ 4. 빌드 결과물 생성                                         │
│    target/nifi-custom-nar-1.0.0.nar                     │
│    → 호스트 머신에 자동으로 나타남                             │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│ 5. 컨테이너 자동 삭제                                       │
│    --rm 옵션으로 빌드 완료 후 자동 정리                        │
└─────────────────────────────────────────────────────────┘
```

#### 장점

- ✅ Java/Maven 설치 불필요
- ✅ 모든 개발자가 동일한 빌드 환경 사용 (Java 21 고정)
- ✅ OS 독립적 (macOS, Windows, Linux 모두 동일)
- ✅ 버전 충돌 없음
- ✅ CI/CD 환경과 동일

#### Maven 캐시

```bash
# 의존성 캐시 디렉토리 (자동 생성)
.m2-docker/
└── repository/
    ├── org/apache/nifi/...
    └── junit/...
```

- 첫 빌드: 의존성 다운로드 (시간 소요)
- 이후 빌드: 캐시 사용 (빠른 속도)

### 2. 로컬 Maven 빌드 (폴백)

Docker가 없는 경우 로컬 Maven을 사용합니다.

#### 요구사항

```bash
# JDK 21 설치 확인
java -version
# openjdk version "21.0.x" 출력되어야 함

# Maven 설치 확인
mvn -version
# Apache Maven 3.9.x 이상
```

#### 설치 방법

**macOS:**
```bash
brew install openjdk@21 maven
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
```

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install openjdk-21-jdk maven
```

**Amazon Linux/RHEL:**
```bash
sudo dnf install java-21-openjdk-devel maven
```

---

## 개발 워크플로우

### 1. 초기 설정

```bash
# 1. 저장소 클론
git clone <repository-url>
cd nifi-deploy

# 2. Docker 실행 확인
docker info

# 3. NiFi 시작 (NAR 자동 빌드 포함)
./scripts/dev/docker-nifi.sh start
```

### 2. 커스텀 프로세서 개발

```bash
# 1. 새 프로세서 클래스 생성
nifi-custom-processors/src/main/java/com/example/MyProcessor.java

# 2. 테스트 작성
nifi-custom-processors/src/test/java/com/example/MyProcessorTest.java

# 3. NAR 빌드 및 NiFi 재로드
./scripts/dev/docker-nifi.sh reload
```

### 3. 테스트 및 디버깅

```bash
# 로그 확인
./scripts/dev/docker-nifi.sh logs

# NiFi 컨테이너 접속
./scripts/dev/docker-nifi.sh shell

# 컨테이너 상태 확인
./scripts/dev/docker-nifi.sh status
```

### 4. NiFi 웹 UI 접속

```
URL: https://localhost:8443/nifi

인증 정보:
- Username: admin
- Password: ctsBtRBKHRAx69EqUghvvgEvjnaLjFEB
```

> **참고**: 자체 서명 인증서 사용으로 보안 경고가 나타날 수 있습니다.
> "고급" → "안전하지 않음(localhost)(으)로 이동"을 클릭하세요.

---

## 스크립트 사용법

### build-nar.sh

NAR 파일을 빌드합니다.

```bash
./scripts/dev/build-nar.sh
```

**동작:**
1. Docker 사용 가능 여부 확인
2. Docker 있음 → Docker 기반 빌드 (Java 21)
3. Docker 없음 → 로컬 Maven 빌드

**결과:**
- `nifi-custom-nar/target/nifi-custom-nar-1.0.0.nar` 생성

### docker-nifi.sh

NiFi Docker 컨테이너를 관리합니다.

#### 시작

```bash
./scripts/dev/docker-nifi.sh start
```

- NAR 파일이 없으면 자동으로 빌드
- NiFi 컨테이너 시작
- 1-2분 후 웹 UI 접속 가능

#### 중지

```bash
./scripts/dev/docker-nifi.sh stop
```

- NiFi 컨테이너 중지 및 삭제
- 데이터는 Docker 볼륨에 보존됨

#### 재시작

```bash
./scripts/dev/docker-nifi.sh restart
```

- 컨테이너만 재시작 (NAR 재빌드 안 함)

#### NAR 재빌드 및 재로드

```bash
./scripts/dev/docker-nifi.sh reload
```

**프로세서 개발 시 주로 사용하는 명령어**

1. NAR 재빌드
2. NiFi 재시작
3. 30-60초 후 새 프로세서 반영

#### 로그 확인

```bash
./scripts/dev/docker-nifi.sh logs
```

- 실시간 로그 스트리밍 (Ctrl+C로 종료)

#### 컨테이너 상태

```bash
./scripts/dev/docker-nifi.sh status
```

- 컨테이너 실행 상태 확인

#### 컨테이너 셸 접속

```bash
./scripts/dev/docker-nifi.sh shell
```

- NiFi 컨테이너 bash 접속
- 로그 확인, 설정 변경 등

#### 데이터 완전 삭제

```bash
./scripts/dev/docker-nifi.sh clean
```

⚠️ **경고**: 모든 NiFi 데이터, 플로우, 설정 삭제

- Docker 볼륨 모두 삭제
- 확인 프롬프트 표시

---

## 환경 설정

### Docker Compose 설정

`scripts/dev/docker-compose.yml`:

```yaml
services:
  nifi:
    image: apache/nifi:2.5.0
    container_name: nifi-dev
    ports:
      - "8443:8443"                    # HTTPS 포트
    environment:
      - NIFI_WEB_HTTPS_HOST=0.0.0.0
      - NIFI_WEB_HTTPS_PORT=8443
      - NIFI_WEB_PROXY_HOST=localhost:8443
      - SINGLE_USER_CREDENTIALS_USERNAME=admin
      - SINGLE_USER_CREDENTIALS_PASSWORD=ctsBtRBKHRAx69EqUghvvgEvjnaLjFEB
    volumes:
      # NAR 파일 마운트
      - ../../nifi-custom-nar/target/nifi-custom-nar-1.0.0.nar:/opt/nifi/nifi-current/lib/nifi-custom-nar-1.0.0.nar:ro
      # 데이터 영속화
      - nifi-database-repository:/opt/nifi/nifi-current/database_repository
      - nifi-flowfile-repository:/opt/nifi/nifi-current/flowfile_repository
      - nifi-content-repository:/opt/nifi/nifi-current/content_repository
      - nifi-provenance-repository:/opt/nifi/nifi-current/provenance_repository
      - nifi-state:/opt/nifi/nifi-current/state
      - nifi-logs:/opt/nifi/nifi-current/logs
```

### 주요 환경 변수

| 변수 | 값 | 설명 |
|------|-----|------|
| `NIFI_WEB_HTTPS_PORT` | 8443 | HTTPS 포트 |
| `NIFI_WEB_PROXY_HOST` | localhost:8443 | 허용할 프록시 호스트 (SNI 검증) |
| `SINGLE_USER_CREDENTIALS_USERNAME` | admin | 관리자 계정 |
| `SINGLE_USER_CREDENTIALS_PASSWORD` | (자동생성) | 관리자 비밀번호 |

---

## Git 워크플로우

### 커밋하지 않는 파일

`.gitignore` 설정:

```gitignore
# Maven 빌드 결과물
target/
.m2-docker/

# NAR 파일
nifi-custom-nar/target/*.nar

# IDE 설정
.idea/
.vscode/

# 인증서
*.pem

# 로그
*.log
```

### 브랜치 전략

```bash
# 기능 개발
git checkout -b feature/my-processor
# 개발 작업...
./scripts/dev/docker-nifi.sh reload  # 테스트
git add .
git commit -m "feat: MyProcessor 추가"

# 버그 수정
git checkout -b bugfix/fix-issue
# 수정 작업...
git commit -m "fix: 프로세서 오류 수정"
```

---

## 트러블슈팅

### 1. Docker 권한 오류

**문제:**
```
Permission denied while trying to connect to the Docker daemon socket
```

**해결:**
```bash
# Docker Desktop이 실행 중인지 확인
docker info

# macOS/Linux
sudo usermod -aG docker $USER
# 로그아웃 후 재로그인

# Windows
# Docker Desktop을 관리자 권한으로 실행
```

### 2. 포트 충돌

**문제:**
```
Error: Port 8443 is already in use
```

**해결:**
```bash
# 8443 포트 사용 중인 프로세스 확인
lsof -i :8443

# 또는 다른 포트로 변경
# docker-compose.yml에서 포트 수정
ports:
  - "9443:8443"
```

### 3. NAR 파일이 NiFi에 로드되지 않음

**문제:**
NiFi UI에서 커스텀 프로세서가 보이지 않음

**해결:**
```bash
# 1. NAR 파일 존재 확인
ls -lh nifi-custom-nar/target/*.nar

# 2. 컨테이너 내부 확인
./scripts/dev/docker-nifi.sh shell
ls -lh /opt/nifi/nifi-current/lib/*.nar
exit

# 3. NiFi 재시작
./scripts/dev/docker-nifi.sh restart

# 4. 로그 확인
./scripts/dev/docker-nifi.sh logs | grep "NAR"
```

### 4. Maven 의존성 다운로드 실패

**문제:**
```
Could not resolve dependencies
```

**해결:**
```bash
# 1. 캐시 삭제 후 재빌드
rm -rf .m2-docker/
./scripts/dev/build-nar.sh

# 2. 네트워크 확인
ping repo.maven.apache.org

# 3. 프록시 설정 (필요 시)
# .m2-docker/settings.xml 생성
```

### 5. HTTPS 인증서 경고

**문제:**
브라우저에서 "Your connection is not private" 경고

**해결:**
- 정상 동작입니다 (자체 서명 인증서 사용)
- "고급" → "localhost(으)로 이동" 클릭
- 또는 브라우저에서 인증서 예외 추가

### 6. 빌드 속도가 느림

**문제:**
첫 빌드 시 10분 이상 소요

**해결:**
```bash
# 정상입니다 - 의존성 다운로드 시간
# 이후 빌드는 캐시로 30초 이내 완료

# 캐시 확인
du -sh .m2-docker/repository/
```

### 7. Java 버전 충돌 (로컬 빌드 시)

**문제:**
```
Unsupported class file major version 65
```

**해결:**
```bash
# Java 21로 변경
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
java -version

# 또는 Docker 빌드 사용 (권장)
./scripts/dev/build-nar.sh
```

---

## 성능 최적화

### Maven 빌드 속도 향상

```bash
# 테스트 스킵 (개발 중)
mvn package -DskipTests

# 병렬 빌드
mvn -T 4 package

# 오프라인 모드 (의존성 다운로드 완료 후)
mvn -o package
```

### Docker 캐시 최적화

```bash
# 불필요한 이미지 정리
docker system prune -a

# Maven 캐시 크기 확인
du -sh .m2-docker/

# 오래된 캐시 삭제 (필요 시)
rm -rf .m2-docker/repository/*
```

---

## 참고 자료

### NiFi 공식 문서
- [Apache NiFi Documentation](https://nifi.apache.org/docs.html)
- [NiFi Developer Guide](https://nifi.apache.org/developer-guide.html)
- [NiFi Processor Development](https://nifi.apache.org/docs/nifi-docs/html/developer-guide.html#developing-processors)

### Docker 문서
- [Docker Desktop](https://docs.docker.com/desktop/)
- [Docker Compose](https://docs.docker.com/compose/)
- [Maven Docker Image](https://hub.docker.com/_/maven)

### Maven 문서
- [Maven Getting Started](https://maven.apache.org/guides/getting-started/)
- [Maven POM Reference](https://maven.apache.org/pom.html)

---

## 라이선스

이 프로젝트는 Apache License 2.0을 따릅니다.
