# Lupang 완전 서버리스 아키텍처 배포 가이드

## 🎯 아키텍처 개요

**완전 서버리스 구조:**
```
User → CloudFront → S3 (Frontend)
     ↓
     → API Gateway → Lambda → DynamoDB
```

### 주요 변경사항
- ❌ 제거: EC2 (Bastion, Jenkins, App Servers), ALB, NAT Gateway
- ✅ 추가: Lambda Functions, API Gateway, CloudFront, S3 Static Hosting

## 📁 프로젝트 구조

```
AWS_-_-/
├── lambda_functions/
│   ├── signup/
│   │   └── index.js
│   ├── login/
│   │   └── index.js
│   └── create_order/
│       └── index.js
├── frontend/
│   ├── index.html
│   ├── login.html
│   ├── signup.html
│   └── product.html
├── lambda.tf           # Lambda 함수 정의
├── api_gateway.tf      # API Gateway 설정
├── frontend_s3.tf      # Frontend S3 버킷
├── cloudfront.tf       # CloudFront 배포
├── database.tf         # DynamoDB 테이블
├── s3.tf              # 이미지 저장용 S3
└── serverless_outputs.tf  # Output 정의
```

## 🚀 배포 단계

### 1. Lambda Dependencies 설치

각 Lambda 함수 디렉터리에서 AWS SDK를 설치해야 합니다:

```bash
# Signup Function
cd lambda_functions/signup
npm init -y
npm install @aws-sdk/client-dynamodb @aws-sdk/lib-dynamodb

# Login Function
cd ../login
npm init -y
npm install @aws-sdk/client-dynamodb @aws-sdk/lib-dynamodb

# Create Order Function
cd ../create_order
npm init -y
npm install @aws-sdk/client-dynamodb @aws-sdk/lib-dynamodb

cd ../..
```

### 2. Frontend HTML 파일 준비

기존 HTML 파일을 frontend 디렉터리에 복사:

```bash
mkdir -p frontend
# HTML 파일들을 frontend/ 폴더에 복사
# (index.html, login.html, signup.html, product.html)
```

### 3. Terraform 배포

```bash
terraform init
terraform plan
terraform apply
```

배포 완료 후 outputs에서 API URLs를 확인하세요:

```bash
terraform output
```

### 4. HTML 파일의 API URL 업데이트

**Terraform outputs에서 얻은 API URLs로 교체:**

#### signup.html
```javascript
// 기존
const LAMBDA_ENDPOINT = 'https://arihkdskh8.execute-api.ap-northeast-2.amazonaws.com/default/LupangSignupFunction';

// 새로운 URL (terraform output signup_api_url)
const LAMBDA_ENDPOINT = '<API_GATEWAY_URL>/signup';
```

#### login.html
```javascript
// 기존
const LOGIN_API_URL = "https://5kldsos529.execute-api.ap-northeast-2.amazonaws.com/default/login";

// 새로운 URL (terraform output login_api_url)
const LOGIN_API_URL = "<API_GATEWAY_URL>/login";
```

#### product.html
```javascript
// 기존
const API_URL = "https://ryhrb4jw49.execute-api.ap-northeast-2.amazonaws.com/default/LupangCreateOrderFunction";

// 새로운 URL (terraform output create_order_api_url)
const API_URL = "<API_GATEWAY_URL>/orders";
```

### 5. Frontend 파일을 S3에 업로드

```bash
# Terraform output에서 S3 버킷 이름 확인
BUCKET_NAME=$(terraform output -raw frontend_s3_bucket)

# S3에 업로드
aws s3 sync ./frontend s3://$BUCKET_NAME/
```

### 6. CloudFront 접속

```bash
# CloudFront URL 확인
terraform output cloudfront_url
```

브라우저에서 CloudFront URL로 접속하면 완료!

## ⚙️ 주요 리소스

### Lambda Functions
- **LupangSignupFunction**: 회원가입 처리
- **LupangLoginFunction**: 로그인 처리
- **LupangCreateOrderFunction**: 주문 생성

### API Gateway Endpoints
- `POST /signup` → LupangSignupFunction
- `POST /login` → LupangLoginFunction
- `POST /orders` → LupangCreateOrderFunction

### S3 Buckets
- **lupang-frontend-{ACCOUNT_ID}**: 프론트엔드 정적 파일
- **lupang-app-storage-{ACCOUNT_ID}**: 이미지 저장

### DynamoDB Tables
- **LupangUsers**: 사용자 정보
- **LupangOrders**: 주문 정보

## 🔍 트러블슈팅

### Lambda 패키지 오류
```bash
# Lambda zip 파일 재생성
cd lambda_functions/signup
zip -r ../signup.zip .
```

### API Gateway CORS 오류
- API Gateway에서 CORS 설정 확인
- `cors_configuration` 블록 확인

### CloudFront 캐시 문제
```bash
# CloudFront 캐시 무효화
aws cloudfront create-invalidation \
  --distribution-id <DISTRIBUTION_ID> \
  --paths "/*"
```

## 💰 비용 최적화

**서버리스의 장점:**
- EC2, NAT Gateway 제거로 월 $50+ 절감
- Lambda 무료 티어: 월 100만 요청
- CloudFront 무료 티어: 월 1TB 전송
- DynamoDB 무료 티어: 25GB 저장

## 📊 모니터링

### CloudWatch Logs
```bash
# Lambda 로그 확인
aws logs tail /aws/lambda/LupangSignupFunction --follow
aws logs tail /aws/lambda/LupangLoginFunction --follow
aws logs tail /aws/lambda/LupangCreateOrderFunction --follow
```

### API Gateway Logs
```bash
# API Gateway 로그 확인
aws logs tail /aws/apigateway/lupang-api --follow
```

## 🔄 기존 EC2 아키텍처와 비교

| 항목 | 기존 (EC2) | 새로운 (Serverless) |
|------|-----------|-------------------|
| 프론트엔드 | EC2 + ALB | CloudFront + S3 |
| 백엔드 | EC2 + ALB | API Gateway + Lambda |
| 데이터베이스 | DynamoDB | DynamoDB (동일) |
| 관리 서버 | Bastion, Jenkins | 없음 |
| 월 비용 | ~$70 | ~$5-10 |
| 스케일링 | 수동 | 자동 |
| 가용성 | 단일 리전 | 글로벌 (CloudFront) |

## ✅ 완료 체크리스트

- [ ] Lambda dependencies 설치 완료
- [ ] Terraform apply 성공
- [ ] HTML 파일 API URL 업데이트
- [ ] Frontend 파일 S3 업로드
- [ ] CloudFront URL 접속 테스트
- [ ] 회원가입 테스트
- [ ] 로그인 테스트
- [ ] 주문 생성 테스트

## 🎉 배포 완료!

이제 완전 서버리스 아키텍처로 Lupang 애플리케이션이 실행됩니다!

문의사항이 있으시면 이슈를 남겨주세요.
