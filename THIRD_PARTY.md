# 사용한 오픈소스

| 이름 | 버전 | 라이선스 | 출처 | 용도 |
|---|---|---|---|---|
| Terraform | 1.9.x | BUSL-1.1 | github.com/hashicorp/terraform | IaC 실행(도구 사용, 재배포 없음) |
| terraform-provider-cloudstack | 0.5.x | MPL-2.0 | registry.terraform.io/providers/cloudstack/cloudstack | Solid Cloud 자원 |
| hashicorp/random, hashicorp/tls | 3.6.x, 4.0.x | MPL-2.0 | registry.terraform.io | 시크릿·자체서명 인증서 |
| Flask | 3.1.0 | BSD-3-Clause | pypi.org/project/Flask | 웹 앱 |
| gunicorn | 23.0.0 | MIT | pypi.org/project/gunicorn | WSGI 서버 |
| psycopg / psycopg-pool | 3.2.3 / 3.2.4 | LGPL-3.0 | pypi.org/project/psycopg | PostgreSQL 드라이버(수정 없이 동적 사용) |
| cryptography | 44.0.1 | Apache-2.0 / BSD | pypi.org/project/cryptography | AES-256-GCM |
| prometheus-client | 0.21.1 | Apache-2.0 | pypi.org/project/prometheus-client | 메트릭 |
| PostgreSQL | 16 | PostgreSQL License | postgresql.org | DB |
| Nginx | 1.24 | BSD-2-Clause | nginx.org | TLS 종단, 리버스 프록시 |
| Keepalived | 2.2.x | GPL-2.0 | keepalived.org | DB 승격 판단(VRRP, 패키지 그대로 사용) |
| HAProxy | 2.8 | GPL-2.0 / LGPL-2.1 | haproxy.org | mon01 로드밸런서(패키지 그대로 사용) |
| Docker Engine / Compose | Ubuntu 24.04 패키지 | Apache-2.0 | docker.com | 앱·모니터링 컨테이너 실행 |
| node-exporter / nginx-prometheus-exporter / postgres_exporter | Ubuntu 24.04 패키지 | Apache-2.0 | github.com/prometheus | 노드·Nginx·DB 지표 |
| pgaudit | Ubuntu 24.04 패키지 | PostgreSQL License | github.com/pgaudit/pgaudit | DB 감사 로그 |
| Graphviz | 2.43 | EPL-1.0 | graphviz.org | 보고서 다이어그램 작성(도구 사용) |
| Prometheus / Blackbox exporter | 2.55.1 / 0.25.0 | Apache-2.0 | prometheus.io | 모니터링 |
| Grafana | 11.5.2 | AGPL-3.0 | grafana.com | 대시보드(수정·재배포 없이 내부 사용) |
| Trivy | 0.76.1 | Apache-2.0 | github.com/aquasecurity/trivy | 취약점·IaC 스캔 |
| Checkov | 3.4.10 | Apache-2.0 | github.com/bridgecrewio/checkov | IaC 정적 분석 |
| TFLint | 0.54.0 | MPL-2.0 | github.com/terraform-linters/tflint | Terraform 린트 |
| Conftest (OPA) | 0.56.0 | Apache-2.0 | github.com/open-policy-agent/conftest | Policy as Code |
| Gitleaks | 8.21.2 | MIT | github.com/gitleaks/gitleaks | 시크릿 스캔 |
| k6 | 2.4.0 | AGPL-3.0 | github.com/grafana/k6 | 부하 테스트(도구 사용) |

서비스 이름 evlocker는 과제용으로 지은 이름이며, 모든 증거 데이터는 테스트용 더미 파일이다.
