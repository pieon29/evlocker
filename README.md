# evlocker · 디지털 증거 보관함 인프라

인프라 설계 및 구축 최종 과제 (32191170 김진우)

- 우선순위: 1순위 보안·규제, 2순위 가용성
- 플랫폼: Solid Cloud (Apache CloudStack), Terraform으로 VPC 3계층과 VM 5대를 배포
- 구성: web01·web02(Nginx TLS + 앱 컨테이너, VR 로드밸런서) · db01·db02(PostgreSQL 스트리밍 복제 + Keepalived VIP 자동 승격) · mon01(Bastion, Prometheus·Grafana, 중앙 로그, 암호화 백업)

## 실행 방법

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
../scripts/ssh-setup.sh
../scripts/policy-check.sh
```

자세한 설계와 측정 결과는 docs/REPORT.md에 있다.
