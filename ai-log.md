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
| 5 | MTU 문제를 cloud-init bootcmd의 일회성 `ip link set`으로 해결된다고 판단 | 이후 네트워크 재설정에서 1500으로 복귀 | 재배포 후 `ip link` 확인 | MSS 클램핑으로 교체 |
| 6 | bootcmd에서 `netplan apply` 실행, netplan 파일로 MTU 고정 | 부팅 중 교착으로 SSH 키 미적용, 이어서 netplan 설정 충돌로 네트워크 소실 | 콘솔 화면 `netplan failed`, 로그인 불가 | netplan 방식 폐기 |
| 7 | 모든 설정과 시크릿을 user-data 하나에 담는 설계 | 일부 VM이 부팅 초반 큰 user-data를 받지 못함. 또 user-data는 VM 안에서 인증 없이 조회 가능해 시크릿 보관 위치로 부적절 | 콘솔 호스트명 비교, 라우터 user-data 대리 조회 | user-data 최소화 + provisioner로 시크릿 전달 |
| 8 | VPC 라우터(VR)의 DHCP·user-data 전달 실패를 매번 설정 문제로 보고 MTU·netplan·user-data 크기 조정을 반복 제안 | 같은 정의에서 VM마다 결과가 달라지는 플랫폼 쪽 불안정이었고, 학생 권한으로는 라우터를 진단할 수 없음 | 7번 조치 후에도 다른 VM(mon01)에서 같은 증상 재현 | 원인 추적을 멈추고 Shared Network로 전환, 결정 근거와 트레이드오프를 리포트에 기록 |
