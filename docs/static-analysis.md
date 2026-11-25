# 정적 분석과 조치 기록

## 1차 실행 (CI run 45542448613, 2026-11-25)

| 도구 | 결과 | 지적 내용 | 조치 |
|---|---|---|---|
| terraform fmt / validate | 통과 | - | - |
| tflint (recommended) | 실패: 경고 2, 오류 1 | modules/vm에 required_version 없음 (terraform_required_version) | required_version = ">= 1.5.0" 추가 |
| | | modules/vm의 cloudstack provider 버전 제약 없음 (terraform_required_providers) | version = "~> 0.5.0" 추가, 루트와 동일하게 고정 |
| | | compute.tf에서 file()이 CI 러너에 없는 ~/.ssh/id_ed25519.pub를 읽다 실패 | fileexists()로 감싸고, 키가 없으면 VPC 생성 전에 precondition으로 plan을 멈추게 변경 |
| gitleaks | 통과 | 커밋 이력에 시크릿 없음 | - |
| pytest (PostgreSQL 16 서비스 컨테이너) | 통과 | - | - |
| trivy config, checkov, conftest | 미실행 | tflint 실패로 뒤 단계가 건너뛰어짐 | 2차 실행에서 확인 |

부가 경고: GitHub Actions의 Node.js 20 지원 종료 경고 → actions/checkout@v5, actions/setup-python@v6으로 올림.
