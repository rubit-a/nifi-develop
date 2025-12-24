# NiFi 운영 환경 배포 가이드

이 디렉토리는 EC2에 Apache NiFi를 HTTP(8080)로 배포하기 위한 스크립트와 설정 파일을 포함합니다.

## 디렉토리 구조

```
prod/
├── nar/                    # 커스텀 NAR 파일 (빌드 시 자동 복사됨)
│   └── nifi-custom-nar-1.0.0.nar
├── script/                 # 배포 스크립트
│   ├── nifi-setup.sh      # NiFi 설치 및 설정 스크립트
│   ├── enable-autostart.sh # 자동 시작 설정 스크립트
│   ├── nifi-start.sh      # NiFi 시작 스크립트
│   └── nifi.service       # systemd 서비스 파일
└── README.md              # 이 파일
```

## 배포 전 준비사항

### 1. 로컬에서 커스텀 NAR 빌드
```bash
cd /path/to/nifi-deploy
./dev/script/build-nar.sh
```
빌드가 완료되면 `prod/nar/` 디렉토리에 NAR 파일이 자동으로 복사됩니다.

### 2. EC2 인스턴스 준비
- **OS**: Amazon Linux 2023
- **Java**: Java 21 (스크립트가 자동 설치)
- **NiFi 버전**: 2.5.0
- **필수 포트 열기**:
  - **8080**: HTTP (NiFi Web UI)

## 배포 방법

### 1. EC2에 파일 전송
```bash
# prod 디렉토리 전체를 EC2로 전송
scp -i your-key.pem -r prod/ ec2-user@your-ec2-ip:/home/ec2-user/
```

### 2. EC2에서 설치 스크립트 실행
```bash
# EC2에 SSH 접속
ssh -i your-key.pem ec2-user@your-ec2-ip

# 스크립트 실행 권한 부여
cd /home/ec2-user/prod/script
chmod +x *.sh

# NiFi 설치 및 설정 실행
./nifi-setup.sh
```

### 3. 설치 과정
스크립트는 다음 단계를 자동으로 수행합니다:

1. **[1/8] Java 설치**: Amazon Corretto 21 설치
2. **[2/8] NiFi 설치**: Apache NiFi 2.5.0 다운로드 및 설치
3. **[3/8] bootstrap.conf 설정**: Java 경로 설정
4. **[4/8] JVM 메모리 설정**: 최소 256MB, 최대 512MB
5. **[5/8] 커스텀 NAR 설치**: `prod/nar/` 디렉토리의 NAR 파일을 `/opt/nifi/lib/`에 복사
6. **[6/8] SSL/TLS 인증서 생성**: HTTP 모드에서는 생략
7. **[7/8] nifi.properties 설정**: HTTP 활성화, HTTPS 비활성화
8. **[8/8] 자동 시작 설정**: systemd 서비스 등록 및 NiFi 시작

## 접속 방법

### HTTP 접속
```
http://your-ec2-ip:8080/nifi
```
### 인증 방식
HTTP 모드에서는 인증이 비활성화됩니다. 운영 환경에서는 HTTPS 또는 리버스 프록시 구성을 권장합니다.

### 브라우저 경고
HTTP 모드라 TLS 인증서 경고가 표시되지 않습니다.

## NiFi 관리 명령어

### 서비스 상태 확인
```bash
sudo systemctl status nifi
```

### 서비스 시작/중지/재시작
```bash
sudo systemctl start nifi
sudo systemctl stop nifi
sudo systemctl restart nifi
```

### 로그 확인
```bash
# 애플리케이션 로그
sudo tail -f /opt/nifi/logs/nifi-app.log

# 부팅 로그
sudo tail -f /opt/nifi/logs/nifi-bootstrap.log

# 사용자 로그
sudo tail -f /opt/nifi/logs/nifi-user.log
```

### 자동 시작 활성화/비활성화
```bash
# 활성화 (이미 스크립트에서 설정됨)
sudo systemctl enable nifi

# 비활성화
sudo systemctl disable nifi
```

## NiFi 제거

설치된 NiFi를 중지/해제하고 `/opt/nifi`와 다운로드 파일을 삭제합니다.

```bash
cd /path/to/nifi-deploy/prod/script
./nifi-remove.sh
```

## 커스텀 NAR 업데이트 방법

### 1. 새 NAR 빌드
```bash
# 로컬에서
cd /path/to/nifi-deploy
./dev/script/build-nar.sh
```

### 2. EC2로 전송
```bash
scp -i your-key.pem prod/nar/nifi-custom-nar-1.0.0.nar ec2-user@your-ec2-ip:/home/ec2-user/
```

### 3. EC2에서 NAR 교체
```bash
# EC2에서
sudo systemctl stop nifi
sudo cp /home/ec2-user/nifi-custom-nar-1.0.0.nar /opt/nifi/lib/
sudo chown ec2-user:ec2-user /opt/nifi/lib/nifi-custom-nar-1.0.0.nar
sudo systemctl start nifi
```

## 트러블슈팅

### NiFi가 시작되지 않는 경우
```bash
# 로그 확인
sudo tail -100 /opt/nifi/logs/nifi-app.log
sudo tail -100 /opt/nifi/logs/nifi-bootstrap.log

# Java 버전 확인
java -version  # Java 21이어야 함

# 포트 사용 확인
sudo netstat -tulpn | grep 8080
```

### 메모리 부족
`/opt/nifi/conf/bootstrap.conf` 파일에서 JVM 메모리 설정 변경:
```bash
sudo vi /opt/nifi/conf/bootstrap.conf

# 다음 줄 수정:
java.arg.2=-Xms512m   # 최소 메모리
java.arg.3=-Xmx1024m  # 최대 메모리
```

## 보안 권장사항

1. **방화벽 설정**: 필요한 포트(8080)만 열기
2. **HTTPS 전환 고려**: 운영 환경에서는 TLS/리버스 프록시 권장
3. **정기 업데이트**: NiFi 및 Java 보안 패치 적용
4. **로그 모니터링**: 주기적인 로그 확인 및 이상 징후 탐지

## 참고 문서

- [Apache NiFi 공식 문서](https://nifi.apache.org/docs.html)
- [NiFi Security 가이드](https://nifi.apache.org/docs/nifi-docs/html/administration-guide.html#security-configuration)
