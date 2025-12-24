#!/bin/bash
set -e

# 프로젝트 루트 디렉토리로 이동
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/../.."
cd "${PROJECT_ROOT}"

echo "========================================="
echo " Building Custom NiFi NAR"
echo "========================================="
echo ""

# Docker Maven 이미지 설정
MAVEN_IMAGE="maven:3.9-eclipse-temurin-21"

# Docker 사용 여부 확인
USE_DOCKER=false
if command -v docker &> /dev/null; then
    if docker info &> /dev/null; then
        USE_DOCKER=true
    fi
fi

# Docker 기반 빌드
if [ "$USE_DOCKER" = true ]; then
    echo "🐳 Using Docker-based build (Java 21)"
    echo "   Image: ${MAVEN_IMAGE}"
    echo ""

    # Maven 로컬 캐시 디렉토리 (빌드 속도 향상)
    MAVEN_CACHE="${PROJECT_ROOT}/.m2-docker"
    mkdir -p "${MAVEN_CACHE}"

    # Docker로 Maven 실행
    docker run --rm \
        -v "${PROJECT_ROOT}:/workspace" \
        -v "${MAVEN_CACHE}:/var/maven/.m2" \
        -e MAVEN_CONFIG=/var/maven/.m2 \
        -w /workspace \
        ${MAVEN_IMAGE} \
        bash -c "
            echo '[1/3] Cleaning previous builds...'
            mvn clean -Duser.home=/var/maven

            echo ''
            echo '[2/3] Running tests...'
            mvn test -Duser.home=/var/maven

            echo ''
            echo '[3/3] Building NAR package...'
            mvn package -DskipTests -Duser.home=/var/maven
        "

    echo ""
    echo "========================================="
    echo " Build completed successfully!"
    echo "========================================="

    # prod/nar 디렉토리에 NAR 파일 복사
    echo ""
    echo "Copying NAR to prod/nar directory..."
    mkdir -p "${PROJECT_ROOT}/prod/nar"
    cp "${PROJECT_ROOT}/nifi-custom-nar/target/nifi-custom-nar-1.0.0.nar" "${PROJECT_ROOT}/prod/nar/"
    echo "✓ NAR copied to prod/nar/nifi-custom-nar-1.0.0.nar"

# 로컬 Maven 빌드 (폴백)
else
    echo "⚠️  Docker not available, using local Maven"
    echo ""

    # Check if Maven is installed
    if ! command -v mvn &> /dev/null; then
        echo "Error: Neither Docker nor Maven is installed"
        echo ""
        echo "Please install one of the following:"
        echo ""
        echo "Option 1 (Recommended): Install Docker"
        echo "  macOS:   https://www.docker.com/products/docker-desktop/"
        echo "  Windows: https://www.docker.com/products/docker-desktop/"
        echo "  Linux:   https://docs.docker.com/engine/install/"
        echo ""
        echo "Option 2: Install Maven + JDK 21"
        echo "  macOS:   brew install maven openjdk@21"
        echo "  Linux:   sudo apt install maven openjdk-21-jdk"
        echo ""
        exit 1
    fi

    # Optional JDK selection (macOS). Honors JAVA_HOME if already set.
    if [ -z "${JAVA_HOME}" ] && [ -x /usr/libexec/java_home ]; then
        if [ -n "${JDK_VERSION}" ]; then
            if /usr/libexec/java_home -v "${JDK_VERSION}" >/dev/null 2>&1; then
                JAVA_HOME_TEMP=$(/usr/libexec/java_home -v "${JDK_VERSION}")
                export JAVA_HOME="${JAVA_HOME_TEMP}"
            else
                echo "Error: JDK ${JDK_VERSION} not found. Set JAVA_HOME manually."
                exit 1
            fi
        elif /usr/libexec/java_home -v 21 >/dev/null 2>&1; then
            JAVA_HOME_TEMP=$(/usr/libexec/java_home -v 21)
            export JAVA_HOME="${JAVA_HOME_TEMP}"
        fi
    fi

    if [ -n "${JAVA_HOME}" ]; then
        export PATH="${JAVA_HOME}/bin:${PATH}"
        echo "Using JAVA_HOME: ${JAVA_HOME}"
    fi

    # Check Java version
    JAVA_VERSION_OUTPUT=$(java -version 2>&1 | head -n 1)
    JAVA_VERSION=$(echo "${JAVA_VERSION_OUTPUT}" | awk -F '"' '{print $2}' | awk -F '.' '{print $1}')
    if [ "${JAVA_VERSION}" != "21" ]; then
        echo "⚠️  Warning: Java ${JAVA_VERSION} detected. NiFi 2.5.0 requires Java 21"
        echo "   Build may fail or produce incompatible binaries"
        echo ""
    fi

    # Clean and build
    echo ""
    echo "[1/3] Cleaning previous builds..."
    mvn clean

    echo ""
    echo "[2/3] Running tests..."
    mvn test

    echo ""
    echo "[3/3] Building NAR package..."
    mvn package -DskipTests

    echo ""
    echo "========================================="
    echo " Build completed successfully!"
    echo "========================================="

    # prod/nar 디렉토리에 NAR 파일 복사
    echo ""
    echo "Copying NAR to prod/nar directory..."
    mkdir -p "${PROJECT_ROOT}/prod/nar"
    cp "${PROJECT_ROOT}/nifi-custom-nar/target/nifi-custom-nar-1.0.0.nar" "${PROJECT_ROOT}/prod/nar/"
    echo "✓ NAR copied to prod/nar/nifi-custom-nar-1.0.0.nar"
fi
