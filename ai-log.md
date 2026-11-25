# AI 활용 기록

## 사용 도구와 방식
- 도구: Claude (대화형 에이전트). 자동 실행·자동 승인 없이, 인프라 명령은 본인이 내용을 확인한 뒤 본인 PC에서 실행했다.
- 사전 지침: 과제 안내서, 1~12주차 실습 가이드, Solid Cloud 사용자 설명서를 먼저 제공하고 그 범위(CloudStack provider 0.5.0, Ubuntu_24.04, 학생 쿼터) 안에서만 코드를 만들게 했다.
- 통과 조건: terraform fmt/validate, tflint, trivy config, checkov, conftest 정책 테스트, gitleaks, pytest가 모두 CI에서 통과해야 반영한다.

## AI에게 맡긴 일
| 단계 | 맡긴 일 | 확인 방법 |
|---|---|---|
| 설계 | 쿼터 안에서의 VM 구성, SPOF 분석 | Limits 화면 값과 대조 |
| 구축 | Terraform, cloud-init, 부트스트랩 스크립트 초안 | fmt/validate/plan, 실제 apply 결과 |
| 앱 | 증거 보관 API, 해시 체인, 암호화 | 로컬 PostgreSQL 16 대상 pytest 8건 |
| 정책 | Rego 정책 7개 | 위반 fixture로 7건 모두 거부되는지 확인 |

## AI가 틀린 사례
| # | AI의 주장·출력 | 실제 | 발견 방법 | 조치 |
|---|---|---|---|---|
| 1 | Solid Cloud를 OpenStack 계열로 가정하고 OpenStack provider·할당량 확인 방법을 안내 | Apache CloudStack, provider는 cloudstack/cloudstack ~> 0.5.0 | 9주차 실습 가이드와 대조 | CloudStack 기준으로 설계 전면 수정 |
| 2 | winget 설치를 관리자 PowerShell에서 하라고 안내 | Terraform winget 패키지는 사용자 범위라 관리자 컨텍스트에서 설치 실패 | 실제 오류 메시지 | 일반 Git Bash에서 설치 |
| 3 | 템플릿·오퍼링 이름 확인용 캡처를 요청 | 이미 1주차 실습 문서에 모두 있었음 | 문서 재확인 | 요청 철회, 문서 값 사용 |
| 4 | 처음 설계안을 Small VM 7대로 제안 | Primary storage 120GB / VM당 루트 20GB라 최대 6대 | Limits 값으로 계산 | 5대 + 여유 1대로 축소 |

(배포·측정 단계에서 추가로 발견되는 오류를 계속 기록한다.)
