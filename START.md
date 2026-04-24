# DevOps 하네스 실행 방법

## 프로젝트 개요

이 프로젝트는 AWS 인프라 배포를 위한 **DevOps 전용 하네스**입니다.
프론트엔드 생성이 아닌, **인프라 코드 생성 및 배포 자동화**를 담당합니다.

**역할 분리**:
- `frontagent`: 프론트엔드 HTML 생성 (Planner → Generator → Evaluator)
- `frontdeploy`: AWS 인프라 배포 (Planner → Generator → Evaluator) ← **이 프로젝트**

---

## 프로젝트 구조

```
frontdeploy/
├── CLAUDE.md                      ← DevOps 오케스트레이터
├── agents/
│   ├── planner.md                 ← 인프라 설계자
│   ├── generator.md               ← 인프라 코드 생성자
│   ├── evaluator.md               ← 인프라 검증자
│   └── evaluation_criteria.md    ← 검증 기준 (보안, 비용, 기능)
│
├── public/                        ← 배포 대상 (frontagent에서 동기화)
├── infra/                         ← 생성된 인프라 코드
│   ├── amplify.yml
│   └── s3-policy.json
├── scripts/                       ← 자동화 스크립트
│   ├── sync-from-frontagent.sh
│   ├── deploy.sh
│   └── test-deployment.sh
│
├── SPEC.md                        ← Planner가 생성 (실행 후)
├── SELF_CHECK.md                  ← Generator가 생성 (실행 후)
├── QA_REPORT.md                   ← Evaluator가 생성 (실행 후)
└── START.md                       ← 지금 이 파일
```

---

## 실행 전 준비사항

### 1. AWS CLI 설정
```bash
# AWS CLI 설치 확인
aws --version

# AWS 자격증명 설정
aws configure
# AWS Access Key ID: [your-access-key]
# AWS Secret Access Key: [your-secret-key]
# Default region: us-east-1
# Default output format: json

# 설정 확인
aws sts get-caller-identity
```

### 2. GitHub Personal Access Token 생성
1. GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token (classic)
3. 권한 선택:
   - `repo` (전체)
   - `admin:repo_hook` (Amplify CI/CD 연동용)
4. 토큰 생성 후 복사

```bash
# 환경 변수로 설정
export GITHUB_TOKEN=ghp_your_token_here
```

### 3. 프로젝트 값 설정
배포하려는 프로젝트의 정보를 준비합니다:
- 도메인명: `fukuoka26.com`
- GitHub 저장소: `your-username/fukuoka26`
- S3 버킷명: `fukuoka26-assets`
- 목표 월 비용: `$1 이하`

---

## 실행 방법

### 1단계: frontdeploy 폴더로 이동
```bash
cd /Users/sangmin/Desktop/Claude/Projects/frontdeploy
```

### 2단계: 배포 요구사항 프롬프트 입력

Claude Code에 한 줄로 요구사항을 입력합니다:

```
fukuoka26.com에 정적 사이트 배포. frontagent/output의 HTML을 S3 이미지와 함께 배포. GitHub push 시 자동 배포. 월 비용 $1 이하.
```

**CLAUDE.md가 자동으로 실행**:
1. **Planner** 서브에이전트 → `SPEC.md` 생성 (AWS 아키텍처 설계서)
2. **Generator** 서브에이전트 → `infra/`, `scripts/` 생성 + `SELF_CHECK.md`
3. **Evaluator** 서브에이전트 → `QA_REPORT.md` 생성 (보안, 비용, 기능 검증)
4. 불합격 시 → Generator가 피드백 반영 재작업 (최대 3회)
5. 합격 시 → 배포 승인 보고

### 3단계: 생성된 인프라 코드 확인

```bash
# 생성된 파일 확인
ls -la infra/
ls -la scripts/

# 설계서 확인
cat SPEC.md

# 검증 보고서 확인
cat QA_REPORT.md
```

### 4단계: 실제 배포 실행

```bash
# frontagent 콘텐츠 동기화
./scripts/sync-from-frontagent.sh

# AWS 리소스 프로비저닝 및 배포
./scripts/deploy.sh

# 배포 검증
./scripts/test-deployment.sh
```

### 5단계: 결과 확인

```bash
# 도메인 접속
open https://fukuoka26.com

# Amplify Console 확인
echo "https://console.aws.amazon.com/amplify/"
```

---

## 다른 프로젝트에 적용하기

프롬프트만 바꾸면 됩니다:

```
myportfolio.com에 포트폴리오 사이트 배포. S3+CloudFront. GitHub Actions CI/CD. 월 $0.50 이하.
```

```
blog.example.com에 정적 블로그 배포. Amplify. 이미지 최적화. 월 $0 목표.
```

```
startup.io에 랜딩페이지 배포. Route53 + CloudFront + S3. HTTPS 강제. 월 $1 이하.
```

**agents/ 폴더의 지시서는 수정 없이 재사용 가능합니다.**
검증 기준을 바꾸고 싶으면 `agents/evaluation_criteria.md`만 수정하세요.

---

## 하네스 vs Solo 비교

하네스 없이 직접 구현한 결과와 비교하고 싶으면:

```bash
# 다른 폴더에서 Claude Code 실행 (CLAUDE.md가 없는 곳)
mkdir manual-deploy && cd manual-deploy

# 같은 요구사항 입력
> fukuoka26.com에 정적 사이트 AWS 배포. Amplify 사용. CI/CD 포함. amplify.yml, deploy.sh 스크립트 작성해줘.
```

**하네스 장점**:
- Planner가 비용, 보안, 확장성을 고려한 설계 제공
- Generator가 멱등성, 에러 핸들링, 롤백 가능한 코드 생성
- Evaluator가 보안 취약점, 비용 초과, Best Practices 위반 자동 검증
- 반복 피드백 루프로 품질 보장 (최대 3회)

Solo는 1회성 코드 생성, 하네스는 **검증된 프로덕션급 인프라 코드** 제공.

---

## 트러블슈팅

### AWS CLI 권한 에러
```bash
# IAM 정책 확인
aws iam get-user

# 필요 권한: AmplifyFullAccess, AmazonS3FullAccess, AmazonRoute53FullAccess
```

### GitHub Token 에러
```bash
# 토큰 유효성 확인
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user
```

### 배포 실패 시
```bash
# Amplify 로그 확인
aws amplify list-apps
aws amplify get-job --app-id [APP_ID] --branch-name main --job-id [JOB_ID]

# 롤백
aws amplify delete-app --app-id [APP_ID]
```

---

## 참고 문서

- Harness Design Pattern: https://www.anthropic.com/engineering/harness-design-long-running-apps
- Claude Code Best Practices: https://code.claude.com/docs/ko/best-practices
- AWS Amplify Docs: https://docs.aws.amazon.com/amplify/
- AWS CLI Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/index.html

---

## 콘텐츠 재배포 워크플로우

인프라가 이미 배포되어 있고, frontagent에서 HTML 콘텐츠를 수정한 후 재배포하는 경우입니다.

### 배경

frontagent 프로젝트에서 HTML 콘텐츠를 수정한 후, 이를 AWS Amplify에 재배포하는 과정입니다.

### 전제 조건

- frontagent/output 디렉토리에 최신 HTML 존재
- AWS Amplify 앱이 이미 배포되어 있음
- GitHub 저장소 연결됨

### 단계별 실행

#### 1. 콘텐츠 동기화

```bash
cd /Users/sangmin/Desktop/Claude/Projects/frontdeploy
./scripts/sync-from-frontagent.sh
```

**자동 처리 내용**:
- frontagent/output → frontdeploy/public 파일 복사
- frontagent/Ref 이미지 → public/images/ 복사
- HTML에서 `../Ref/` → `/images/` 경로 자동 수정
- 백업 파일(.bak, .backup) 제외

**예상 출력**:
```
Syncing content from frontagent/output to public/...
✓ Images copied to public/images/
✓ Image paths fixed (../Ref/ → /images/)
Verifying copied images:
- checklist.png
- emergency.png
- history.png
- infukuoka.png
Sync completed!
```

#### 2. 변경사항 확인

```bash
git status
git diff public/
```

변경된 HTML 파일과 이미지 파일을 확인합니다.

#### 3. Git Commit & Push

```bash
git add public/
git commit -m "Update homepage content from frontagent"
git push origin main
```

**Amplify 자동 동작**:
- GitHub webhook → Amplify 빌드 트리거
- amplify.yml 설정에 따라 빌드 (5-10분)
- CloudFront 캐시 무효화
- 새 버전 배포

#### 4. 배포 확인

**Amplify 콘솔**:
```bash
open "https://console.aws.amazon.com/amplify/home?region=us-east-1"
```

**사이트 확인**:
- https://fukuoka26.com
- https://fukuoka26.com/checklist.html
- https://fukuoka26.com/history.html
- https://fukuoka26.com/in-fukuoka.html

각 페이지에서 배경 이미지가 정상적으로 표시되는지 확인합니다.

#### 5. 테스트 스크립트 실행 (선택)

```bash
./scripts/test-deployment.sh
```

HTTPS 리다이렉트, SSL 인증서, S3 이미지 로딩 등을 자동으로 검증합니다.

---

### 빠른 실행 (스킬 사용)

위 모든 단계를 자동으로 실행하려면:

```
/deploy
```

또는

```
"홈페이지 재배포"
```

스킬이 자동으로 sync → git add → commit → push를 실행합니다.

---

### 문제 해결

#### 이미지가 로딩되지 않는 경우

```bash
# public/images/ 디렉토리 확인
ls -la public/images/

# HTML 경로 확인 (../Ref/가 있으면 안 됨)
grep -r "../Ref/" public/*.html

# 경로가 잘못되었다면 다시 sync
./scripts/sync-from-frontagent.sh
```

#### Git push 실패

```bash
# 원격 저장소 확인
git remote -v

# SSH 키 또는 Personal Access Token 재설정
```

#### Amplify 빌드 실패

1. Amplify 콘솔에서 빌드 로그 확인
2. public/ 디렉토리가 비어있지 않은지 확인
3. amplify.yml 설정 확인

---

### 주의사항

- **백업 파일은 Git에 커밋하지 마세요**: .bak, .backup, .bak2 파일들
- **sync 전에 frontagent에서 콘텐츠 최종 확인**: 한 번 push하면 즉시 배포됨
- **CloudFront 캐시**: 변경사항이 즉시 반영 안 될 수 있음 (최대 24시간, 보통 10분)

