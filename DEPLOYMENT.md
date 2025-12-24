# NiFi EC2 자동 배포 가이드

## 📋 개요

이 프로젝트는 GitHub Actions를 통해 master 브랜치에 푸시될 때 자동으로 EC2에 배포됩니다.

## 🚀 자동 배포 설정

### 1. GitHub Secrets 설정

GitHub 저장소의 Settings > Secrets and variables > Actions에서 다음 Secrets를 추가합니다:

| Secret 이름 | 설명 | 예시 |
|------------|------|------|
| `EC2_SSH_KEY` | EC2 접속용 Private SSH Key | `-----BEGIN RSA PRIVATE KEY-----\n...` |
| `EC2_HOST` | EC2 인스턴스 Public DNS | `ec2-xx-xx-xx-xx.compute.amazonaws.com` |
| `EC2_USER` | EC2 접속 사용자 | `ec2-user` (Amazon Linux 기본값) |

#### EC2_SSH_KEY 생성 및 설정 방법

EC2_SSH_KEY는 GitHub Actions가 EC2에 접속하기 위한 Private SSH 키입니다.

**방법 1: 기존 EC2 키페어 사용 (권장)**

EC2 인스턴스 생성 시 다운로드한 `.pem` 키를 사용합니다.

```bash
# 1. EC2 생성 시 다운로드한 .pem 키 내용 확인
cat ~/Downloads/your-ec2-key.pem

# 2. 출력된 전체 내용을 복사
# -----BEGIN RSA PRIVATE KEY----- 부터
# -----END RSA PRIVATE KEY----- 까지 전체 복사

# 3. GitHub Secrets에 EC2_SSH_KEY 이름으로 추가
```

**방법 2: 새로운 SSH 키 생성 및 EC2에 등록**

기존 키가 없거나 새로운 키를 사용하고 싶은 경우:

```bash
# 1. 로컬에서 새로운 SSH 키 생성
ssh-keygen -t rsa -b 4096 -f ~/.ssh/github-actions-ec2 -N ""

# 2. Public 키를 EC2에 등록
# Public 키 내용 복사
cat ~/.ssh/github-actions-ec2.pub

# 3. EC2에 SSH로 접속하여 authorized_keys에 추가
ssh -i ~/Downloads/your-ec2-key.pem ec2-user@<EC2_HOST>

# EC2에서 실행:
echo "복사한_public_키_내용" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
exit

# 4. 로컬에서 연결 테스트
ssh -i ~/.ssh/github-actions-ec2 ec2-user@<EC2_HOST>

# 5. Private 키를 GitHub Secrets에 등록
cat ~/.ssh/github-actions-ec2
# 출력된 전체 내용을 GitHub Secrets의 EC2_SSH_KEY에 추가
```

**GitHub Secrets 등록 단계:**

1. GitHub 저장소 → **Settings** 탭
2. 왼쪽 메뉴 → **Secrets and variables** → **Actions**
3. **New repository secret** 클릭
4. Name: `EC2_SSH_KEY`
5. Secret: Private 키 전체 내용 붙여넣기
   ```
   -----BEGIN RSA PRIVATE KEY-----
   MIIEpAIBAAKCAQEA...
   (전체 내용)
   ...
   -----END RSA PRIVATE KEY-----
   ```
6. **Add secret** 클릭

**주의사항:**
- Private 키(.pem 또는 id_rsa)는 절대 Git에 커밋하지 마세요
- Public 키(.pub)만 EC2에 등록합니다
- Private 키는 GitHub Secrets에만 안전하게 보관됩니다

#### EC2_HOST 확인 방법

```bash
# AWS Console > EC2 > Instances에서 Public IPv4 DNS 확인
# 또는 EC2 인스턴스에서 실행:
curl http://169.254.169.254/latest/meta-data/public-hostname
```

### 2. EC2 보안 그룹 설정

EC2 인스턴스의 보안 그룹에서 다음 포트를 허용합니다:

- **SSH (22)**: GitHub Actions에서 접속
- **HTTP (8080)**: NiFi Web UI 접속

### 3. EC2 초기 설정

**🎉 완전 자동화!** EC2 초기 설정이 필요 없습니다!

GitHub Actions가 NiFi 설치 여부를 자동으로 확인하고, 설치되지 않은 경우 자동으로 설치 및 설정을 진행합니다.

**처음 배포 시 자동으로 수행되는 작업:**
1. Java 21 자동 설치
2. NiFi 2.5.0 다운로드 및 설치
3. NiFi 설정 (HTTP, 메모리 등)
4. Systemd 서비스 등록 및 자동 시작 설정
5. NAR 파일 배포

**이후 배포:**
- NiFi가 이미 설치되어 있으면 NAR 파일만 업데이트

## 📦 배포 워크플로우

### 자동 배포 (GitHub Actions)

```mermaid
graph LR
    A[Push to master] --> B[GitHub Actions 트리거]
    B --> C[Maven 빌드]
    C --> D[NAR 파일 생성]
    D --> E[EC2로 SCP 전송]
    E --> F[NiFi 재시작]
    F --> G[배포 완료]
```

**트리거 조건:**
- `master` 브랜치에 푸시될 때 자동 실행
- Actions 탭에서 수동 실행 가능 (workflow_dispatch)

**배포 단계:**
1. JDK 21 설정 및 Maven 빌드
2. NAR 파일 생성
3. EC2 SSH 연결 및 NiFi 설치 확인
   - **NiFi 미설치 시**: 자동으로 Java + NiFi 설치 및 설정
   - **NiFi 설치됨**: 다음 단계로 진행
4. NAR 파일을 EC2로 SCP 전송
5. 기존 NAR 백업
6. 새 NAR 설치 및 NiFi 재시작

### 수동 배포 (로컬)

로컬에서 직접 배포할 수도 있습니다:

```bash
# 1. NAR 빌드
./dev/script/build-nar.sh

# 2. EC2에 배포
./prod/script/deploy-to-ec2.sh <EC2_HOST>

# 예시:
./prod/script/deploy-to-ec2.sh ec2-12-34-56-78.compute.amazonaws.com
```

## 🔍 배포 확인

### GitHub Actions 로그 확인

1. GitHub 저장소 > Actions 탭 이동
2. 최근 워크플로우 실행 확인
3. 각 단계별 로그 확인

### EC2에서 NiFi 상태 확인

```bash
# SSH로 EC2 접속
ssh ec2-user@<EC2_HOST>

# NiFi 상태 확인
sudo systemctl status nifi

# NiFi 로그 확인
tail -f /opt/nifi/logs/nifi-app.log

# 설치된 NAR 확인
ls -lh /opt/nifi/lib/nifi-custom-nar-*.nar
```

### NiFi Web UI 접속

브라우저에서 접속:
```
http://<EC2_PUBLIC_IP>:8080/nifi
```

## 🛠️ 트러블슈팅

### 1. SSH 연결 실패

**문제:** `Permission denied (publickey)`

**해결:**
```bash
# SSH 키 권한 확인
ls -l ~/.ssh/id_rsa  # 600 이어야 함

# GitHub Secret의 EC2_SSH_KEY가 올바른지 확인
# - 개행 문자(\n)가 포함되어야 함
# - -----BEGIN RSA PRIVATE KEY----- 부터 -----END RSA PRIVATE KEY----- 까지 전체 복사
```

### 2. NAR 파일이 적용되지 않음

**문제:** Custom Processor가 NiFi에서 보이지 않음

**해결:**
```bash
# EC2에서 NiFi 완전히 재시작
sudo systemctl stop nifi
sleep 5
sudo systemctl start nifi

# NiFi 로그에서 NAR 로딩 확인
grep -i "custom" /opt/nifi/logs/nifi-app.log
```

### 3. 빌드 실패

**문제:** Maven 빌드 오류

**해결:**
```bash
# 로컬에서 빌드 테스트
./dev/script/build-nar.sh

# 의존성 문제 해결
mvn dependency:purge-local-repository
mvn clean install
```

### 4. 메모리 부족

**문제:** EC2 인스턴스 메모리 부족으로 NiFi 시작 실패

**해결:**
```bash
# bootstrap.conf에서 메모리 설정 확인
cat /opt/nifi/conf/bootstrap.conf | grep -E "Xms|Xmx"

# 필요시 메모리 줄이기
sudo sed -i 's/java.arg.2=.*/java.arg.2=-Xms128m/' /opt/nifi/conf/bootstrap.conf
sudo sed -i 's/java.arg.3=.*/java.arg.3=-Xmx256m/' /opt/nifi/conf/bootstrap.conf

sudo systemctl restart nifi
```

## 📚 추가 자료

- [NiFi 공식 문서](https://nifi.apache.org/docs.html)
- [GitHub Actions 문서](https://docs.github.com/en/actions)
- [AWS EC2 보안 그룹 설정](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-security-groups.html)

## 🔄 롤백 방법

배포 후 문제가 발생하면 이전 버전으로 롤백할 수 있습니다:

```bash
# EC2에 접속
ssh ec2-user@<EC2_HOST>

# 백업된 NAR 목록 확인
ls -lt /opt/nifi/lib/backup-*/

# 이전 NAR로 복구
sudo systemctl stop nifi
sudo cp /opt/nifi/lib/backup-YYYYMMDD-HHMMSS/nifi-custom-nar-*.nar /opt/nifi/lib/
sudo systemctl start nifi
```

## ⚙️ 고급 설정

### 특정 브랜치만 배포

`.github/workflows/deploy-ec2.yml` 수정:

```yaml
on:
  push:
    branches:
      - master
      - production  # production 브랜치 추가
```

### 배포 전 테스트 실행

워크플로우에 테스트 단계 추가:

```yaml
- name: Run Tests
  run: mvn test
```

### Slack 알림 추가

배포 결과를 Slack으로 전송:

```yaml
- name: Slack Notification
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```