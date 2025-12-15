# 트러블슈팅 가이드

프로젝트 진행 중 자주 발생하는 문제들과 해결방법을 정리했습니다.

---

## Phase 1 (3-Tier 아키텍처) 트러블슈팅

### 1. ALB 헬스체크 실패 - 인스턴스가 계속 Unhealthy 상태

**증상**
- Auto Scaling Group에서 인스턴스가 생성되자마자 종료됨
- Target Group에서 인스턴스 상태가 계속 "unhealthy"
- ALB 접속 시 503 Service Unavailable 에러

**원인**
- Nginx가 제대로 시작되지 않음
- 헬스체크 grace period가 너무 짧음 (인스턴스 부팅 시간 부족)
- 보안 그룹에서 ALB → App Server 80번 포트 막혀있음

**해결방법**

1. **user-data 로그 확인**
```bash
# Bastion에서 App 서버로 접속 후
ssh ec2-user@<APP_SERVER_PRIVATE_IP>
sudo cat /var/log/user-data.log
```

2. **Nginx 상태 확인**
```bash
sudo systemctl status nginx
sudo systemctl start nginx  # 시작 안됐으면 수동 시작
```

3. **헬스체크 경로 확인**
```bash
curl localhost/
# 200 OK 응답이 와야 함
```

4. **보안 그룹 확인**
- App SG의 Inbound: ALB SG로부터 80번 포트 허용되어 있는지 확인

5. **설정 수정**
- `alb.tf`의 `health_check_grace_period`를 300초로 늘림 (이미 적용됨)
- `health_check` matcher에 "200,301,302" 추가 (이미 적용됨)

---

### 2. Bastion에서 App Server로 SSH 접속 안됨

**증상**
- `ssh ec2-user@<PRIVATE_IP>` 시 Connection timeout
- "No route to host" 에러

**원인**
- Private Key를 Bastion에 업로드 안함
- App Server 보안 그룹에서 Bastion SSH 허용 안됨
- Private Subnet에 NAT Gateway 없음

**해결방법**

1. **Private Key를 Bastion으로 복사**
```bash
# 로컬에서 실행
scp -i phase1_ec2_rds/lupang-key.pem \
    phase1_ec2_rds/lupang-key.pem \
    ec2-user@<BASTION_PUBLIC_IP>:~/

# Bastion에서
chmod 400 lupang-key.pem
```

2. **보안 그룹 확인**
- App SG Inbound에 Bastion SG로부터 22번 포트 허용 확인

3. **App 서버 Private IP 확인**
```bash
# AWS CLI 사용
aws ec2 describe-instances \
  --filters "Name=tag:ManagedBy,Values=AutoScaling" \
  --query 'Reservations[*].Instances[*].[PrivateIpAddress,State.Name]' \
  --output table
```

---

### 3. RDS 접속 안됨 (Connection refused)

**증상**
- App 서버에서 RDS 접속 시 "Can't connect to MySQL server" 에러
- Timeout 발생

**원인**
- RDS 보안 그룹에서 App Server 접근 허용 안됨
- RDS 엔드포인트 주소 틀림
- DB 생성 중 (아직 available 상태 아님)

**해결방법**

1. **RDS 상태 확인**
```bash
aws rds describe-db-instances \
  --db-instance-identifier phase1-lupang-primary \
  --query 'DBInstances[0].DBInstanceStatus'
```

2. **RDS 엔드포인트 확인**
```bash
terraform output rds_primary_endpoint
# 또는
aws rds describe-db-instances \
  --db-instance-identifier phase1-lupang-primary \
  --query 'DBInstances[0].Endpoint.Address'
```

3. **보안 그룹 확인**
- RDS SG Inbound: App SG로부터 3306번 포트 허용되어 있는지 확인

4. **MySQL 클라이언트로 접속 테스트**
```bash
# App 서버에서
mysql -h <RDS_ENDPOINT> -u admin -p
# 비밀번호 입력
```

---

### 4. NAT Gateway 비용이 너무 많이 나옴

**증상**
- 9시간만 썼는데 NAT Gateway 비용이 1달러 넘게 나옴

**원인**
- NAT Gateway는 시간당 과금 + 데이터 전송량 과금
- Multi-AZ로 NAT Gateway 2개 띄워서 비용 2배

**해결방법**

1. **개발/테스트 환경이면 NAT Gateway 1개만 사용**
```hcl
# vpc.tf 수정
resource "aws_nat_gateway" "main" {
  # for_each 대신 single NAT Gateway
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public["ap-northeast-2a"].id
}

# Private Route Table도 모두 하나의 NAT Gateway 사용
resource "aws_route" "private_nat" {
  for_each               = aws_route_table.private
  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id  # 동일한 NAT Gateway
}
```

2. **사용 안할 때는 인프라 전체 내리기**
```bash
terraform destroy -auto-approve
```

3. **Production에서는 Multi-AZ NAT Gateway 유지** (고가용성 위해)

---

### 5. Auto Scaling이 작동 안함 (서버가 안 늘어남)

**증상**
- CPU 사용률이 70% 넘어도 인스턴스가 추가로 안 뜸
- CloudWatch에서 메트릭은 보이는데 스케일링 안됨

**원인**
- Scaling Policy가 제대로 설정 안됨
- CloudWatch 알람이 생성 안됨
- Desired Capacity가 이미 Max와 같음

**해결방법**

1. **Auto Scaling Group 상태 확인**
```bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names phase1-app-asg
```

2. **Scaling Policy 확인**
```bash
aws autoscaling describe-policies \
  --auto-scaling-group-name phase1-app-asg
```

3. **CloudWatch 알람 확인**
```bash
aws cloudwatch describe-alarms
```

4. **수동으로 Desired Capacity 늘려서 테스트**
```bash
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name phase1-app-asg \
  --desired-capacity 3
```

5. **CPU 부하 테스트**
```bash
# App 서버에서
sudo yum install -y stress
stress --cpu 2 --timeout 300s  # 5분간 CPU 부하
```

---

## Phase 2 (서버리스) 트러블슈팅

### 6. Lambda 함수 실행 시 DynamoDB 접근 권한 없음

**증상**
- Lambda 실행 시 "User is not authorized to perform: dynamodb:PutItem" 에러
- API Gateway에서 500 Internal Server Error

**원인**
- Lambda IAM Role에 DynamoDB 권한 없음
- DynamoDB 테이블 이름이 틀림

**해결방법**

1. **Lambda 로그 확인**
```bash
aws logs tail /aws/lambda/LupangSignupFunction --follow
```

2. **IAM Role 권한 확인**
```bash
aws iam list-attached-role-policies --role-name lupang-lambda-role
```

3. **lambda.tf에서 권한 확인**
```hcl
# 이미 적용되어 있음
resource "aws_iam_role_policy_attachment" "lambda_dynamodb" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}
```

4. **Lambda 환경변수 확인**
```bash
aws lambda get-function-configuration \
  --function-name LupangSignupFunction \
  --query 'Environment.Variables'
```

---

### 7. API Gateway CORS 에러

**증상**
- 브라우저 콘솔에 "No 'Access-Control-Allow-Origin' header" 에러
- OPTIONS 요청은 성공하는데 POST 요청은 실패

**원인**
- API Gateway CORS 설정이 안되어 있음
- Lambda 응답에 CORS 헤더 없음

**해결방법**

1. **API Gateway CORS 설정 확인** (이미 적용됨)
```hcl
# api_gateway.tf
cors_configuration {
  allow_origins = ["*"]
  allow_methods = ["GET", "POST", "OPTIONS"]
  allow_headers = ["Content-Type", "Authorization"]
}
```

2. **Lambda 함수에서 응답 헤더 추가**
```javascript
// Lambda 함수에서
return {
  statusCode: 200,
  headers: {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
    'Content-Type': 'application/json'
  },
  body: JSON.stringify(result)
};
```

---

### 8. CloudFront에서 S3 접근 안됨 (403 Forbidden)

**증상**
- CloudFront URL로 접속 시 403 Forbidden
- S3 직접 URL은 작동함

**원인**
- CloudFront OAC 설정 문제
- S3 버킷 정책에 CloudFront 허용 안됨

**해결방법**

1. **S3 버킷 정책 확인**
```bash
aws s3api get-bucket-policy --bucket <BUCKET_NAME>
```

2. **CloudFront 배포 상태 확인**
```bash
aws cloudfront list-distributions \
  --query 'DistributionList.Items[0].Status'
# "Deployed" 상태여야 함
```

3. **frontend_s3.tf에서 버킷 정책 확인** (이미 적용됨)
```hcl
resource "aws_s3_bucket_policy" "frontend_policy" {
  # CloudFront OAC 허용하는 정책
}
```

4. **CloudFront 캐시 무효화**
```bash
aws cloudfront create-invalidation \
  --distribution-id <DISTRIBUTION_ID> \
  --paths "/*"
```

---

### 9. Lambda Cold Start로 인한 타임아웃

**증상**
- 첫 요청은 항상 느림 (5-10초)
- 이후 요청은 빠름
- 가끔 Gateway Timeout (504) 에러

**원인**
- Lambda Cold Start (함수가 처음 실행되거나 한동안 안쓰다가 실행될 때)
- Lambda 타임아웃 설정이 너무 짧음

**해결방법**

1. **Lambda 타임아웃 늘리기**
```hcl
# lambda.tf
resource "aws_lambda_function" "signup" {
  timeout = 30  # 기본 3초 → 30초로 증가
}
```

2. **Provisioned Concurrency 사용** (비용 추가)
```hcl
resource "aws_lambda_provisioned_concurrency_config" "signup" {
  function_name                     = aws_lambda_function.signup.function_name
  provisioned_concurrent_executions = 1
  qualifier                         = aws_lambda_function.signup.version
}
```

3. **CloudWatch에서 실행 시간 모니터링**
```bash
aws logs insights start-query \
  --log-group-name /aws/lambda/LupangSignupFunction \
  --start-time $(date -d '1 hour ago' +%s) \
  --end-time $(date +%s) \
  --query-string 'fields @duration | stats avg(@duration), max(@duration)'
```

---

### 10. DynamoDB 쓰기 실패 (Provisioned throughput exceeded)

**증상**
- 트래픽 많을 때 "ProvisionedThroughputExceededException" 에러
- 일부 요청만 실패

**원인**
- DynamoDB Read/Write Capacity 부족
- On-Demand 모드가 아닌 Provisioned 모드 사용 중

**해결방법**

1. **현재 설정 확인**
```bash
aws dynamodb describe-table --table-name lupang-users
```

2. **On-Demand 모드로 변경** (이미 적용됨)
```hcl
# 이미 billing_mode = "PAY_PER_REQUEST"로 설정되어 있음
```

3. **CloudWatch에서 Throttle 모니터링**
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name UserErrors \
  --dimensions Name=TableName,Value=lupang-users \
  --statistics Sum \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300
```

---

## 공통 트러블슈팅

### 11. Terraform apply 실패 - 리소스 이미 존재

**증상**
- `terraform apply` 시 "AlreadyExists" 에러
- "Error creating resource: EntityAlreadyExists"

**원인**
- 이전에 수동으로 만든 리소스와 이름 충돌
- Terraform state와 실제 인프라 불일치

**해결방법**

1. **기존 리소스 Import**
```bash
terraform import aws_s3_bucket.app_bucket lupang-images-bucket
```

2. **리소스 이름 변경**
```hcl
# s3.tf
resource "aws_s3_bucket" "app_bucket" {
  bucket = "lupang-images-bucket-v2"  # 이름 변경
}
```

3. **State 초기화 후 재배포** (주의: 모든 리소스 삭제됨)
```bash
terraform destroy -auto-approve
rm -rf .terraform terraform.tfstate*
terraform init
terraform apply
```

---

### 12. AWS CLI 권한 없음

**증상**
- `aws` 명령어 실행 시 "AccessDenied" 에러
- Terraform apply 시 권한 에러

**원인**
- AWS Credentials 설정 안됨
- IAM 사용자 권한 부족

**해결방법**

1. **Credentials 설정**
```bash
aws configure
# Access Key ID 입력
# Secret Access Key 입력
# Region: ap-northeast-2
```

2. **현재 사용자 확인**
```bash
aws sts get-caller-identity
```

3. **필요한 IAM 권한**
- EC2FullAccess
- RDSFullAccess
- S3FullAccess
- VPCFullAccess
- IAMFullAccess (Lambda 역할 생성 위해)
- CloudFrontFullAccess
- DynamoDBFullAccess

---

### 13. 비용이 예상보다 많이 나옴

**증상**
- 예상보다 AWS 청구 금액이 높음

**주요 원인**

1. **NAT Gateway** - 시간당 $0.045 + 데이터 전송 비용
2. **RDS** - 계속 켜져있으면 한 달에 $30-40
3. **ELB** - 시간당 과금 + LCU 비용
4. **Elastic IP** - 사용 안하는 EIP는 시간당 과금

**해결방법**

1. **사용 안할 때는 인프라 내리기**
```bash
terraform destroy -auto-approve
```

2. **Cost Explorer에서 비용 확인**
```bash
# AWS Console → Billing → Cost Explorer
```

3. **Budget 알람 설정**
```bash
# AWS Console → Billing → Budgets
# 월 예산 $10 설정 후 80% 도달 시 알람
```

4. **주요 비용 절감 팁**
- NAT Gateway: 개발 환경에서는 1개만 사용
- RDS: 개발 환경에서는 t3.micro 사용
- 야간/주말에는 인프라 전체 종료

---

## 디버깅 유용한 명령어 모음

### Phase 1 디버깅
```bash
# ALB 타겟 상태 확인
aws elbv2 describe-target-health \
  --target-group-arn <TARGET_GROUP_ARN>

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
```

---

**발표 팁**: 이런 트러블슈팅 경험을 언급하면 실제로 직접 구축해봤다는 신뢰성을 줄 수 있어요!
