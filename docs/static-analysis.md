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

## 2차 실행 (CI run 45544574216, 2026-11-25)

| 도구 | 결과 | 지적 내용 | 조치 |
|---|---|---|---|
| tflint, trivy config, checkov, conftest 정책 테스트 | 통과 | 1차 조치 후 지적 0건. 정책 테스트는 정상 plan 통과, 위반 plan 7개 규칙 모두 거부 | - |
| gitleaks, pytest | 통과 | - | - |
| trivy image (CRITICAL, 고친 버전 있는 것만) | 실패: 7건 | 베이스 이미지 python:3.12.8-slim-bookworm(Debian 12.9)의 OS 패키지. libgnutls30 CVE-2026-33845, CVE-2026-42010 / libssl3·openssl CVE-2026-31789 / perl-base CVE-2026-13221, CVE-2026-42496, CVE-2026-8376. Python 패키지는 0건 | 최종 스테이지에 apt-get upgrade를 넣어 Debian 보안 업데이트 적용(고친 버전: gnutls 3.7.9-2+deb12u7, openssl 3.0.19-1~deb12u2, perl 5.36.0-7+deb12u4) |

트레이드오프: apt-get upgrade는 빌드 시점마다 패키지 버전이 달라질 수 있어 재현성이 약간 떨어진다. 대신 이미지 태그를 커밋 SHA로 고정하고, 빌드마다 Trivy 게이트를 통과한 이미지만 레지스트리에 올리는 것으로 보완한다.
