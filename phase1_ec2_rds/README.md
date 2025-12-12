# Phase 1: 초기 1인 전자상거래 아키텍처

## 🏗️ 아키텍처 개요

**초기 단계 - 전통적인 3-Tier 웹 아키텍처**

```
User → Internet Gateway
       ↓
       → ALB (Public Subnet)
          ↓
          → App Servers (Private Subnet)
             ↓
             → RDS MySQL (Private Subnet - Multi-AZ)
             → S3 (이미지 저장)

Admin → SSH → Bastion Host → Jenkins Server
```

## 📊 구성 요소

### Networking
- **VPC**: 10.0.0.0/16
- **Public Subnets**: 2개 (AZ-A, AZ-C)
- **Private Subnets**: 2개 (AZ-A, AZ-C)
- **Internet Gateway**: Public Subnet 인터넷 연결
- **NAT Gateway**: 2개 (각 AZ별) - Private Subnet 아웃바운드

### Compute
- **Bastion Host**: SSH 접속용 (Public Subnet)
- **Jenkins Server**: CI/CD (Private Subnet)
- **App Servers**: 2개 (각 AZ별 Private Subnet)

### Database
- **RDS MySQL (Primary)**: 상품, 주문 데이터
- **RDS MySQL (Read Replica)**: 읽기 전용 복제본

### Load Balancer
- **ALB**: HTTP/HTTPS 트래픽 분산

### Storage
- **S3**: 상품 이미지 저장

## 🚀 배포 순서

```bash
# 1. Phase 1 디렉터리로 이동
cd phase1_ec2_rds

# 2. Terraform 초기화
terraform init

# 3. 배포 계획 확인
terraform plan

# 4. 배포 실행
terraform apply

# 5. Outputs 확인
terraform output
```

## 💰 예상 비용 (월)

- EC2 (t2.micro × 4): ~$30
- RDS (db.t3.micro × 2): ~$30
- NAT Gateway × 2: ~$60
- ALB: ~$20
- **총 예상 비용: ~$140/월**

## 🔄 Phase 2로 마이그레이션

서버리스로 전환 시 상위 디렉터리의 코드 사용:
```bash
cd ..
terraform apply
```
