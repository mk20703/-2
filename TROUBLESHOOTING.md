# 트러블슈팅 가이드

프로젝트 진행 중 실제로 발생한 문제들과 해결방법을 정리했습니다.

---

## Phase 1 (3-Tier 아키텍처) 트러블슈팅

### 1. ALB 헬스체크 실패 - 인스턴스가 계속 Unhealthy 상태

**증상**
- Auto Scaling Group에서 인스턴스가 생성되자마자 종료됨
- Target Group에서 인스턴스 상태가 계속 "unhealthy"
- ALB 접속 시 503 Service Unavailable 에러

**원인**
1. **헬스체크 grace period가 너무 짧음**
   - 인스턴스 부팅 및 Nginx 설치 시간이 필요한데 30초는 부족함
   - user-data 스크립트 실행이 완료되기 전에 헬스체크가 시작됨

2. **보안 그룹에서 ALB → App Server 80번 포트 막혀있음**
   - App Server 보안 그룹의 Inbound 규칙에서 ALB로부터의 HTTP 트래픽 차단

**해결방법**

**1) 헬스체크 grace period 늘리기**

```hcl
# alb.tf - Auto Scaling Group 설정
resource "aws_autoscaling_group" "app" {
  name                = "phase1-app-asg"

  # ✅ 30초 → 300초(5분)로 증가
  health_check_grace_period = 300
  health_check_type         = "ELB"

  # ... 나머지 설정
}
```

**왜 300초인가?**
- yum update: ~60초
- Node.js 설치: ~45초
- Nginx 설치 및 시작: ~30초
- 기타 패키지 설치: ~30초
- 여유 시간: ~135초
- **총 약 5분 필요**

**2) 보안 그룹 규칙 수정**

```hcl
# security_groups.tf
resource "aws_security_group" "app" {
  name        = "phase1-app-sg"
  description = "Security group for App servers"
  vpc_id      = aws_vpc.main.id

  # ✅ ALB로부터 HTTP 트래픽 허용
  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]  # ALB 보안 그룹 참조
  }

  # ... 나머지 설정
}
```

**3) 헬스체크 설정 개선**

```hcl
# alb.tf - Target Group 설정
resource "aws_lb_target_group" "app" {
  name     = "phase1-lupang-app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200,301,302"  # ✅ Nginx 리다이렉트 응답도 정상으로 처리
  }
}
```

**4) 문제 확인 방법**

```bash
# 1. Bastion으로 접속
ssh -i phase1_ec2_rds/lupang-key.pem ec2-user@<BASTION_PUBLIC_IP>

# 2. App 서버 Private IP 확인
aws ec2 describe-instances \
  --filters "Name=tag:ManagedBy,Values=AutoScaling" \
  --query 'Reservations[*].Instances[*].[PrivateIpAddress,State.Name]' \
  --output table

# 3. App 서버로 접속
ssh ec2-user@<APP_SERVER_PRIVATE_IP>

# 4. user-data 로그 확인
sudo cat /var/log/user-data.log

# 5. Nginx 상태 확인
sudo systemctl status nginx

# 6. 헬스체크 경로 테스트
curl localhost/
# 200 OK 또는 301/302 응답이 와야 함
```

---

### 2. Bastion에서 App Server로 SSH 접속 안됨

**증상**
- `ssh ec2-user@<PRIVATE_IP>` 시 Connection timeout
- "No route to host" 에러

**원인**
- **App Server 보안 그룹에서 Bastion SSH 허용 안됨**
  - App Server SG의 Inbound에 Bastion SG로부터의 22번 포트 허용 규칙 누락

**해결방법**

**1) 보안 그룹 규칙 추가**

```hcl
# security_groups.tf
resource "aws_security_group" "app" {
  name        = "phase1-app-sg"
  description = "Security group for App servers"
  vpc_id      = aws_vpc.main.id

  # HTTP from ALB
  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # ✅ SSH from Bastion 추가
  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]  # Bastion SG 참조
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

**2) Private Key를 Bastion으로 복사**

```bash
# 로컬에서 실행
scp -i phase1_ec2_rds/lupang-key.pem \
    phase1_ec2_rds/lupang-key.pem \
    ec2-user@<BASTION_PUBLIC_IP>:~/

# Bastion에서 권한 설정
chmod 400 lupang-key.pem
```

**3) SSH 접속 테스트**

```bash
# Bastion에서
ssh -i lupang-key.pem ec2-user@<APP_SERVER_PRIVATE_IP>
```

**4) 문제 확인 방법**

```bash
# 보안 그룹 규칙 확인
aws ec2 describe-security-groups \
  --group-ids <APP_SG_ID> \
  --query 'SecurityGroups[0].IpPermissions'

# App 서버가 실행 중인지 확인
aws ec2 describe-instances \
  --filters "Name=tag:ManagedBy,Values=AutoScaling" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PrivateIpAddress]'
```

---

### 3. RDS 접속 안됨 (Connection refused)

**증상**
- Bastion에서 RDS 접속 시 "Can't connect to MySQL server" 에러
- App 서버에서는 접속 가능하지만 Bastion에서는 접속 불가

**원인**
- **RDS 보안 그룹에서 App Server만 접근 허용**
  - RDS SG의 Inbound 규칙이 App Server SG만 허용하고 Bastion SG는 허용하지 않음
  - 운영 중 디버깅이나 데이터 확인을 위해 Bastion에서도 접근 필요

**해결방법**

**1) RDS 보안 그룹에 Bastion 접근 규칙 추가**

```hcl
# security_groups.tf
resource "aws_security_group" "rds" {
  name        = "phase1-rds-sg"
  description = "Security group for RDS MySQL"
  vpc_id      = aws_vpc.main.id

  # MySQL from App Servers
  ingress {
    description     = "MySQL from App Servers"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  # ✅ MySQL from Bastion 추가 (디버깅 및 관리 목적)
  ingress {
    description     = "MySQL from Bastion"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "RDS Security Group"
    Environment = "Phase1"
  }
}
```

**2) Terraform 적용**

```bash
cd phase1_ec2_rds
terraform plan   # 변경사항 확인
terraform apply  # 적용
```

**3) Bastion에서 MySQL 클라이언트 설치 및 접속**

```bash
# Bastion에 MySQL 클라이언트 설치
sudo yum install -y mysql

# RDS Primary 엔드포인트 확인
terraform output rds_primary_endpoint

# MySQL 접속 테스트
mysql -h <RDS_ENDPOINT> -u admin -p
# 비밀번호 입력 (terraform.tfvars에 설정한 db_password)
```

**4) 접속 확인 명령어**

```sql
-- MySQL 접속 후
SHOW DATABASES;
USE lupangdb;
SHOW TABLES;
SELECT VERSION();
```

**5) 문제 확인 방법**

```bash
# 1. RDS 상태 확인
aws rds describe-db-instances \
  --db-instance-identifier phase1-lupang-primary \
  --query 'DBInstances[0].[DBInstanceStatus,Endpoint.Address]'

# 2. RDS 보안 그룹 규칙 확인
aws ec2 describe-security-groups \
  --group-ids <RDS_SG_ID> \
  --query 'SecurityGroups[0].IpPermissions'

# 3. 네트워크 연결 테스트 (Bastion에서)
telnet <RDS_ENDPOINT> 3306
# "Connected to..." 메시지가 나오면 네트워크 연결 OK

# 4. MySQL 접속 로그 확인 (RDS CloudWatch Logs)
aws rds describe-db-log-files \
  --db-instance-identifier phase1-lupang-primary
```

**보안 고려사항**
- **Production 환경**에서는 Bastion에서 RDS 직접 접근을 제한하는 것이 좋음
- 필요 시에만 임시로 보안 그룹 규칙 추가 후 작업 완료 후 제거
- 개발/테스트 환경에서는 디버깅 편의를 위해 허용 권장

---

## Phase 2 (서버리스) 트러블슈팅

### 1. 로그인 폼 API 통신 오류

**증상**
- 로그인 폼 제출 시 "서버 통신 중 오류가 발생했습니다" 에러 메시지 출력
- 브라우저 콘솔에서 API 호출이 실행되지 않음
- 사용자 로그인 불가

**원인**
- **JavaScript 코드에서 API 엔드포인트 호출 로직 누락**
  - `fetch()` 함수를 이용한 실제 서버 통신 코드가 없음
  - try-catch 구조가 불완전함 (try 블록 없이 catch만 존재)
  - 응답 처리 로직이 누락됨

**문제 코드**

```javascript
// login.html 내부 JavaScript
const LOGIN_API_URL = "https://5kldsos529.execute-api.ap-northeast-2.amazonaws.com/default/login";

document.getElementById('loginForm').addEventListener('submit', async function(e) {
    e.preventDefault();
    const email = document.getElementById('email').value;
    const password = document.getElementById('password').value;
    const errorDiv = document.getElementById('errorMessage');

    errorDiv.style.display = 'none';
    errorDiv.textContent = '';

    // ❌ 여기서 API 호출 코드가 누락됨

} catch (error) {
    console.error('Login Error:', error);
    errorDiv.style.display = 'block';
    errorDiv.textContent = '서버 통신 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
}
```

**해결방법**

**1) 완전한 코드로 수정**

```javascript
const LOGIN_API_URL = "https://5kldsos529.execute-api.ap-northeast-2.amazonaws.com/default/login";

document.getElementById('loginForm').addEventListener('submit', async function(e) {
    e.preventDefault();

    const email = document.getElementById('email').value;
    const password = document.getElementById('password').value;
    const errorDiv = document.getElementById('errorMessage');

    // 에러 메시지 초기화
    errorDiv.style.display = 'none';
    errorDiv.textContent = '';

    try {
        // ✅ API 호출 추가
        const response = await fetch(LOGIN_API_URL, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                email: email,
                password: password
            })
        });

        // ✅ 응답 데이터 파싱
        const data = await response.json();

        // ✅ 응답 상태 확인
        if (!response.ok) {
            throw new Error(data.message || '로그인에 실패했습니다.');
        }

        // ✅ 성공 시 처리
        console.log('Login Success:', data);
        alert('로그인 성공!');

        // 로그인 성공 후 상품 페이지로 리다이렉트
        window.location.href = 'product.html';

    } catch (error) {
        console.error('Login Error:', error);
        errorDiv.style.display = 'block';
        errorDiv.textContent = error.message || '서버 통신 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
    }
});
```

**2) 수정된 login.html 파일을 S3에 업로드**

```bash
# S3 버킷 이름 확인
terraform output s3_frontend_bucket_name

# 수정된 파일 업로드
aws s3 cp login.html s3://<BUCKET_NAME>/login.html \
  --content-type "text/html"
```

**3) CloudFront 캐시 무효화**

```bash
# CloudFront Distribution ID 확인
terraform output cloudfront_distribution_id

# 캐시 무효화
aws cloudfront create-invalidation \
  --distribution-id <DISTRIBUTION_ID> \
  --paths "/login.html"
```

**4) 테스트**

```bash
# 브라우저 개발자 도구 열기 (F12)
# Network 탭에서 다음 확인:
# 1. login API 호출 확인
# 2. Request Payload에 email, password 포함 확인
# 3. Response 상태 코드 확인 (200 OK 또는 에러)
```

**개선 포인트**

1. **로딩 상태 표시 추가**
```javascript
// 로그인 버튼 비활성화
const submitBtn = document.querySelector('button[type="submit"]');
submitBtn.disabled = true;
submitBtn.textContent = '로그인 중...';

try {
    // API 호출
    // ...
} finally {
    // 버튼 다시 활성화
    submitBtn.disabled = false;
    submitBtn.textContent = '로그인';
}
```

2. **입력 유효성 검사 추가**
```javascript
// 이메일 형식 검증
if (!email.includes('@')) {
    errorDiv.style.display = 'block';
    errorDiv.textContent = '올바른 이메일 형식을 입력해주세요.';
    return;
}

// 비밀번호 길이 검증
if (password.length < 6) {
    errorDiv.style.display = 'block';
    errorDiv.textContent = '비밀번호는 최소 6자 이상이어야 합니다.';
    return;
}
```

---

### 2. Lambda 함수 실행 시 DynamoDB 접근 권한 없음

**증상**
- Lambda 실행 시 "User is not authorized to perform: dynamodb:PutItem" 에러
- API Gateway에서 500 Internal Server Error
- CloudWatch Logs에 권한 관련 에러 메시지

**원인**
1. **Lambda IAM Role에 DynamoDB 권한 없음**
   - Lambda 함수를 실행하는 IAM Role에 DynamoDB 테이블 접근 권한 미부여

2. **DynamoDB 테이블 이름이 틀림**
   - Lambda 코드에서 참조하는 테이블 이름과 실제 테이블 이름 불일치

**해결방법**

**1) Lambda 로그 확인**

```bash
# 실시간 로그 확인
aws logs tail /aws/lambda/LupangSignupFunction --follow

# 최근 에러 로그 검색
aws logs filter-log-events \
  --log-group-name /aws/lambda/LupangSignupFunction \
  --filter-pattern "ERROR"
```

**예시 에러 로그:**
```
[ERROR] AccessDeniedException: User: arn:aws:sts::123456789012:assumed-role/lupang-lambda-role/LupangSignupFunction
is not authorized to perform: dynamodb:PutItem on resource: arn:aws:dynamodb:ap-northeast-2:123456789012:table/lupang-users
```

**2) IAM Role 권한 확인**

```bash
# Lambda Role에 연결된 정책 확인
aws iam list-attached-role-policies --role-name lupang-lambda-role

# 출력 예시:
# {
#     "AttachedPolicies": [
#         {
#             "PolicyName": "AWSLambdaBasicExecutionRole",
#             "PolicyArn": "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
#         }
#     ]
# }
# ❌ DynamoDB 권한 정책이 없음!
```

**3) lambda.tf에서 DynamoDB 권한 추가**

```hcl
# lambda.tf
resource "aws_iam_role" "lambda_role" {
  name = "lupang-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# CloudWatch Logs 권한
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ✅ DynamoDB 권한 추가
resource "aws_iam_role_policy_attachment" "lambda_dynamodb" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}
```

**보안 강화: 최소 권한 원칙 적용**

```hcl
# 더 안전한 방법: 특정 테이블에만 권한 부여
resource "aws_iam_role_policy" "lambda_dynamodb_policy" {
  name = "lambda-dynamodb-access"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:UpdateItem"
        ]
        Resource = [
          aws_dynamodb_table.users.arn,
          aws_dynamodb_table.orders.arn,
          aws_dynamodb_table.products.arn
        ]
      }
    ]
  })
}
```

**4) Terraform 적용**

```bash
terraform plan   # 변경사항 확인
terraform apply  # 적용
```

**5) Lambda 환경변수 확인**

```bash
# Lambda 환경변수 확인
aws lambda get-function-configuration \
  --function-name LupangSignupFunction \
  --query 'Environment.Variables'

# 출력 예시:
# {
#     "USERS_TABLE": "lupang-users",
#     "ORDERS_TABLE": "lupang-orders"
# }
```

**6) DynamoDB 테이블 이름 일치 확인**

```bash
# 실제 생성된 DynamoDB 테이블 목록 확인
aws dynamodb list-tables

# Lambda 코드에서 사용하는 테이블 이름 확인
cat lambda_functions/signup/index.js | grep TableName
```

**Lambda 함수 코드에서 환경변수 사용**

```javascript
// lambda_functions/signup/index.js
const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { PutCommand, DynamoDBDocumentClient } = require("@aws-sdk/lib-dynamodb");

const client = new DynamoDBClient({ region: "ap-northeast-2" });
const docClient = DynamoDBDocumentClient.from(client);

exports.handler = async (event) => {
    // ✅ 환경변수에서 테이블 이름 가져오기
    const tableName = process.env.USERS_TABLE;

    const body = JSON.parse(event.body);

    const params = {
        TableName: tableName,  // 환경변수 사용
        Item: {
            email: body.email,
            username: body.username,
            password: body.password,  // 실제로는 해시 처리 필요
            createdAt: new Date().toISOString()
        }
    };

    try {
        await docClient.send(new PutCommand(params));
        return {
            statusCode: 200,
            headers: {
                'Access-Control-Allow-Origin': '*',
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ message: '회원가입 성공!' })
        };
    } catch (error) {
        console.error('DynamoDB Error:', error);
        return {
            statusCode: 500,
            headers: {
                'Access-Control-Allow-Origin': '*',
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ message: 'DynamoDB 오류가 발생했습니다.' })
        };
    }
};
```

**7) Lambda 환경변수 설정**

```hcl
# lambda.tf
resource "aws_lambda_function" "signup" {
  filename         = data.archive_file.signup_lambda.output_path
  function_name    = "LupangSignupFunction"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  runtime         = "nodejs18.x"
  source_code_hash = data.archive_file.signup_lambda.output_base64sha256

  # ✅ 환경변수 설정
  environment {
    variables = {
      USERS_TABLE = aws_dynamodb_table.users.name
      ORDERS_TABLE = aws_dynamodb_table.orders.name
      PRODUCTS_TABLE = aws_dynamodb_table.products.name
    }
  }

  tags = {
    Name        = "Lupang Signup Function"
    Environment = "Production"
  }
}
```

**8) 테스트**

```bash
# Lambda 함수 직접 테스트
aws lambda invoke \
  --function-name LupangSignupFunction \
  --payload '{"body":"{\"email\":\"test@test.com\",\"username\":\"testuser\",\"password\":\"test123\"}"}' \
  response.json

# 응답 확인
cat response.json

# DynamoDB에 데이터가 들어갔는지 확인
aws dynamodb scan --table-name lupang-users
```

**문제 예방 체크리스트**

- [ ] Lambda IAM Role에 DynamoDB 권한 부여
- [ ] Lambda 환경변수에 정확한 테이블 이름 설정
- [ ] Lambda 코드에서 환경변수 사용
- [ ] Terraform apply 후 Lambda 함수 재배포 확인
- [ ] CloudWatch Logs에서 에러 로그 확인

---

## 디버깅 유용한 명령어 모음

### Phase 1 디버깅
```bash
# ALB 타겟 상태 확인
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw alb_target_group_arn)

# Auto Scaling 활동 로그
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name phase1-app-asg \
  --max-records 10

# EC2 인스턴스 목록
aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=Phase1" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PrivateIpAddress]'

# RDS 연결 테스트
telnet <RDS_ENDPOINT> 3306

# 보안 그룹 규칙 확인
aws ec2 describe-security-groups \
  --group-ids <SECURITY_GROUP_ID> \
  --query 'SecurityGroups[0].IpPermissions'
```

### Phase 2 디버깅
```bash
# Lambda 로그 실시간 보기
aws logs tail /aws/lambda/LupangSignupFunction --follow

# API Gateway 테스트
curl -X POST https://<API_ID>.execute-api.ap-northeast-2.amazonaws.com/signup \
  -H "Content-Type: application/json" \
  -d '{"username":"test","email":"test@test.com","password":"test123"}'

# DynamoDB 데이터 확인
aws dynamodb scan --table-name lupang-users

# CloudFront 캐시 삭제
aws cloudfront create-invalidation \
  --distribution-id <DISTRIBUTION_ID> \
  --paths "/*"

# Lambda 환경변수 확인
aws lambda get-function-configuration \
  --function-name LupangSignupFunction \
  --query 'Environment.Variables'

# IAM Role 권한 확인
aws iam list-attached-role-policies --role-name lupang-lambda-role
```

---

**발표 팁**: 이런 트러블슈팅 경험을 언급하면 실제로 직접 구축해봤다는 신뢰성을 줄 수 있어요!
