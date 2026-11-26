# evlocker · 디지털 증거 보관함 인프라

인프라 설계 및 구축 최종 과제 (32191170 김진우)

- 우선순위: 1순위 보안·규제, 2순위 가용성
- 플랫폼: Solid Cloud (Apache CloudStack) Shared Network, Terraform으로 VM 5대를 배포
- 구성: mon01(단일 진입점: HAProxy 로드밸런서 + Bastion, Prometheus·Grafana, 중앙 로그, 암호화 백업) · web01·web02(Nginx TLS + 앱 컨테이너) · db01·db02(PostgreSQL 스트리밍 복제 + Keepalived 자동 승격, 앱은 멀티호스트 연결로 주 DB 자동 탐색)
- 분리: 네트워크 계층 대신 호스트 방화벽(ufw)과 pg_hba를 IP 단위(/32)로 제한. 외부에서 닿는 포트는 mon01의 22·80·443뿐
- 설계 변경 이력: 처음에는 VPC 3계층으로 구축했으나 VPC 라우터의 DHCP·user-data 전달이 VM마다 불안정해 Shared Network로 전환(docs/troubleshooting.md 7·8번)

## 실행 방법

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# api_key, secret_key, shared_network_id, repo_ref, app_image 입력
terraform init
terraform plan
terraform apply
../scripts/ssh-setup.sh
../scripts/policy-check.sh
```

자세한 설계와 측정 결과는 docs/REPORT.md에 있다.
