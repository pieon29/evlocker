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
| 9 | 백업 파일 보호를 위해 백업 스크립트 전체에 `umask 077` 적용을 제안 | 같은 스크립트가 만드는 지표 파일까지 root 전용이 되어 node-exporter가 읽지 못함. 그대로 두면 30분 뒤 "백업 중단" 오경보 | Grafana "Last backup age" No data, 지표 파일 권한 `-rw-------` | 지표 파일만 0644로 교체. 이후 변경 시 해당 파일을 읽는 다른 프로세스를 먼저 확인하도록 절차화 |
| 10 | HAProxy를 TCP 모드로 두고 Nginx에서 접속자별 요청 제한을 거는 설계 | LB 뒤에서는 모든 요청의 출발지가 mon01 하나라, 제한이 전체 제한으로 동작하고 접속기록에 실제 IP가 남지 않으며 /metrics 접근 통제도 무력화 | stress 테스트 실패율 76% + 노드별 요청 수가 50 req/s에서 평평 | PROXY protocol v2, 모니터링 포트 분리 |
| 11 | 포트 점검 스크립트(Git Bash의 timeout + /dev/tcp) 결과를 그대로 신뢰 | web02:22를 열림으로 잘못 판정(오탐) | ufw·iptables 규칙 확인과 PC에서 직접 SSH 시도로 교차 검증 | 결과를 단독 근거로 쓰지 않고 교차 검증 결과를 함께 기록 |
| 12 | probe 요약의 `outage_window_s`(첫 실패~마지막 실패 간격)를 중단 시간처럼 제시하고, 실패 시각 추출 awk 명령도 첫 행 실패 시 기준값이 비는 버그가 있었음 | 두 번의 짧은 중단 사이 간격(65.8초)이 중단 시간처럼 보임 | 실패 시각을 직접 뽑아 보고, HAProxy 로그와 대조 | 보고서에는 실패 건수와 서버 로그 기준 원인만 사용 |

