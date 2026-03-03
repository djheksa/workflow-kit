# AWS 인프라 모니터

AWS 인프라 정보를 자동으로 수집하여 `/tmp/infra-snapshot.md`에 저장한다.
Claude Code가 AWS 작업 시 이 스냅샷을 참조하여 현재 인프라 상태를 파악한다.

## 기능

- 12개 AWS 서비스 정보 자동 수집 (EC2, RDS, ECS, Lambda, S3, CloudFront 등)
- SwiftBar 메뉴바에서 수집 상태 확인 + 수동 트리거
- Claude Code AWS 작업 시 스냅샷 자동 참조 (`.claude/rules/aws.md`)

## 요구사항

- AWS CLI 설치 및 인증 설정 (`aws configure`)
- 적절한 IAM 읽기 권한
- SwiftBar (메뉴바 상태 표시 시)

## 파일

- `infra-snapshot/snapshot.sh` — 스냅샷 수집 스크립트
- `infra-snapshot/scripts/start.sh` — 백그라운드 서비스 시작
- `swiftbar/infra-snapshot.5s.sh` — SwiftBar 플러그인

## 설치

### 1. AWS CLI 설정

```bash
aws configure
# AWS Access Key ID, Secret, Region 입력
```

### 2. 최초 스냅샷 수집

```bash
bash infra-snapshot/snapshot.sh
```

`/tmp/infra-snapshot.md` 생성 확인.

### 3. 자동 갱신 서비스 시작 (선택)

```bash
bash infra-snapshot/scripts/start.sh
```

### 4. SwiftBar 플러그인 설치 (선택)

```bash
ln -s "$(pwd)/swiftbar/infra-snapshot.5s.sh" ~/SwiftBar/infra-snapshot.5s.sh
```

## Claude Code 연동

AWS 관련 작업 요청 시 Claude Code가 자동으로 `/tmp/infra-snapshot.md`를 먼저 읽는다.
규칙 파일: `.claude/rules/aws.md`

> 스냅샷이 없거나 오래된 경우 Claude가 직접 알림을 준다.
