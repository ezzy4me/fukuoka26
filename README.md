# frontdeploy - DevOps Deployment Harness

AWS 인프라 배포를 위한 3-Agent DevOps 하네스 시스템

## 개요

이 프로젝트는 **Harness Engineering Pattern**을 적용한 DevOps 전용 배포 자동화 시스템입니다.

**역할**:
- 사용자의 간단한 요구사항 (1-4문장)을 받아
- AWS 인프라 아키텍처를 설계하고
- 실행 가능한 인프라 코드를 생성하며
- 보안, 비용, 기능을 자동 검증합니다

**frontagent와의 관계**:
- `frontagent`: 프론트엔드 HTML 생성 하네스
- `frontdeploy`: AWS 인프라 배포 하네스 (이 프로젝트)

---

## 3-Agent 구조

### 1. Planner (인프라 설계자)
- **역할**: AWS 인프라 아키텍처 설계
- **입력**: 사용자 배포 요구사항 (1-4문장)
- **출력**: `SPEC.md` (상세 인프라 설계서)
- **설계 원칙**: 보안 우선, 비용 최적화, 확장 가능, 운영 간소화

### 2. Generator (인프라 코드 생성자)
- **역할**: SPEC.md를 실행 가능한 코드로 변환
- **입력**: `SPEC.md`, `evaluation_criteria.md`
- **출력**:
  - `infra/amplify.yml` - Amplify 빌드 설정
  - `infra/s3-policy.json` - S3 버킷 정책
  - `scripts/deploy.sh` - AWS 리소스 프로비저닝
  - `scripts/sync-from-frontagent.sh` - 콘텐츠 동기화
  - `scripts/test-deployment.sh` - 배포 검증
  - `SELF_CHECK.md` - 자가 검증 보고서
- **코드 원칙**: 멱등성, 에러 핸들링, 롤백 가능, 문서화

### 3. Evaluator (인프라 검증자)
- **역할**: 생성된 인프라 코드와 배포 환경 검증
- **입력**: `SPEC.md`, 생성된 코드, `evaluation_criteria.md`
- **출력**: `QA_REPORT.md` (검증 보고서)
- **검증 항목**:
  - 보안 (40%): S3 정책, HTTPS, IAM 권한
  - 기능 (25%): 페이지 접근, 도메인 연결, CI/CD
  - 비용 (20%): 프리 티어 활용, 월 예상 비용
  - Best Practices (15%): 코드 품질, 모니터링, 문서화
- **판정**: 7.0/10 이상 합격, 5.0 미만 불합격

---

## 실행 방법

### 전제 조건
- AWS CLI 설정 완료 (`aws configure`)
- GitHub Personal Access Token 준비
- 배포 대상 정보 (도메인, 저장소명, S3 버킷명)

### 빠른 시작

```bash
cd frontdeploy
```

Claude Code에 입력:
```
fukuoka26.com에 정적 사이트 배포. frontagent/output의 HTML을 S3 이미지와 함께 배포. GitHub push 시 자동 배포. 월 비용 $1 이하.
```

하네스가 자동으로:
1. Planner → `SPEC.md` 생성
2. Generator → `infra/`, `scripts/` 생성
3. Evaluator → `QA_REPORT.md` 생성
4. 피드백 루프 (최대 3회)
5. 합격 시 배포 승인

자세한 내용은 [`START.md`](./START.md)를 참고하세요.

---

## 프로젝트 구조

```
frontdeploy/
├── README.md                      ← 이 파일
├── START.md                       ← 실행 가이드
├── CLAUDE.md                      ← DevOps 오케스트레이터
│
├── agents/                        ← 하네스 에이전트
│   ├── planner.md                 ← 인프라 설계자
│   ├── generator.md               ← 인프라 코드 생성자
│   ├── evaluator.md               ← 인프라 검증자
│   └── evaluation_criteria.md    ← 검증 기준
│
├── public/                        ← 배포 대상 (frontagent 동기화)
├── infra/                         ← 생성된 인프라 코드
├── scripts/                       ← 자동화 스크립트
│
├── SPEC.md                        ← Planner 생성 (실행 후)
├── SELF_CHECK.md                  ← Generator 생성 (실행 후)
└── QA_REPORT.md                   ← Evaluator 생성 (실행 후)
```

---

## 하네스 vs Solo

| 항목 | Solo (단일 프롬프트) | Harness (3-Agent) |
|------|---------------------|-------------------|
| 설계 품질 | 기본적 구현 | 보안, 비용, 확장성 고려 설계 |
| 코드 품질 | 1회성 코드 | 멱등성, 에러 핸들링, 롤백 |
| 검증 | 수동 확인 필요 | 자동 검증 (보안, 비용, 기능) |
| 반복 개선 | 없음 | 피드백 루프 (최대 3회) |
| 프로덕션 준비 | 추가 작업 필요 | 즉시 배포 가능 |

---

## 예시 사용 사례

### 1. 정적 사이트 배포
```
example.com에 포트폴리오 사이트 배포. S3+CloudFront. GitHub Actions. 월 $0.50 이하.
```

### 2. 이미지 저장소 포함 배포
```
blog.io에 블로그 배포. Amplify. S3에 이미지 저장. 자동 배포. 월 $1 이하.
```

### 3. 커스텀 도메인 배포
```
startup.com에 랜딩페이지 배포. Route53 + CloudFront. HTTPS 강제. CI/CD.
```

---

## 검증 기준

### 보안 (40%)
- S3 버킷 퍼블릭 액세스 적절 설정
- HTTPS 강제 적용
- IAM 최소 권한 원칙
- 민감 정보 Git 제외

### 기능 (25%)
- 모든 페이지 HTTP 200
- 도메인 연결 동작
- SSL 인증서 유효
- CI/CD 자동 배포

### 비용 최적화 (20%)
- 프리 티어 최대 활용
- 월 예상 비용 목표 달성
- 불필요한 리소스 없음

### Best Practices (15%)
- 코드 품질 (멱등성, 에러 핸들링)
- 모니터링 설정
- 문서화 충분
- 롤백 전략 존재

---

## 기술 스택

- **AWS Services**: Amplify, S3, Route 53, CloudFront, IAM
- **IaC**: amplify.yml, S3 bucket policies
- **Scripts**: Bash (deploy, sync, test)
- **CI/CD**: GitHub + Amplify (또는 GitHub Actions)
- **Monitoring**: CloudWatch Logs, Alarms

---

## 참고 문서

- [Harness Design Pattern](https://www.anthropic.com/engineering/harness-design-long-running-apps)
- [Claude Code Best Practices](https://code.claude.com/docs/ko/best-practices)
- [AWS Amplify Documentation](https://docs.aws.amazon.com/amplify/)
- [AWS CLI Reference](https://awscli.amazonaws.com/v2/documentation/api/latest/index.html)

---

## 라이선스

MIT License

---

## 기여

이슈 및 PR 환영합니다.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 작성자

Generated with [Claude Code](https://claude.com/claude-code)
