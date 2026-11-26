# 트러블슈팅 기록

| # | 증상 | 원인 | 확인 방법 | 조치 |
|---|---|---|---|---|
| 1 | terraform plan: `contents of id_ed25519.pub are not valid UTF-8` | Windows 컴퓨터 이름이 한글이라 ssh-keygen이 공개키 주석을 CP949로 저장 | 오류 메시지, 프롬프트의 깨진 호스트명 | 공개키 주석만 `pieon@evlocker`로 교체(키 본문은 유지) |
| 2 | 1차 배포 후 모든 VM의 부트스트랩 미실행, cloud-init `status: error` | terraform.tfvars의 repo_url이 예시 값(REPLACE_GITHUB_ID) 그대로라 git clone이 인증을 요구하며 실패 | /var/log/cloud-init-output.log의 `could not read Username` | tfvars 수정, 다음부터 plan 전에 `grep repo_url terraform.tfvars`로 확인 |
| 3 | mon01→web01 SSH가 키 교환(KEX_ECDH_REPLY)에서 멈춤, GitHub 다운로드가 16KB에서 멈춤 | VPC 내부 경로 MTU가 1450인데 VM NIC는 1500이라 큰 패킷이 조용히 버려지는 PMTU 블랙홀 | `ping -M do -s 1472` 실패 / `-s 1422` 성공, MTU 1400 적용 후 GitHub 119,095바이트 다운로드 성공 | cloud-init bootcmd로 모든 NIC MTU를 1400으로 설정(var.vm_mtu), 매 부팅 적용 |
| 4 | MTU 1400 적용 후 재배포했는데 mon01 MTU가 다시 1500, Docker Hub 이미지 다운로드가 중간에 멈추고 TLS handshake timeout | bootcmd의 `ip link set`은 일회성이라 이후 네트워크 재설정(netplan/networkd)이 1500으로 되돌림 | `ip link show ens3` → mtu 1500, `ping -M do -s 1422` 성공·1472 실패 | netplan 설정(90-evl-mtu.yaml)에 mtu 1400과 `dhcp4-overrides.use-mtu: false`를 고정하고 netplan apply, Docker 데몬 MTU 1400, 이미지 pull 재시도 추가 |
| 5 | 4번 조치 후 재배포에서 SSH 키와 콘솔 비밀번호가 모두 적용되지 않음(`Permission denied (publickey)`) | cloud-init bootcmd 안에서 `netplan apply`가 systemd 서비스 재시작을 기다리며 부팅 중인 cloud-init과 교착, 이후 모듈(ssh 키, chpasswd)이 실행되지 않음 | 직전 배포(bootcmd에 netplan apply 없음)에서는 키가 정상 등록됨, 변경점이 이 한 줄뿐, 콘솔 비밀번호도 미적용 | bootcmd에서는 설정 파일 작성과 `ip link set`만 하고, `netplan apply`는 runcmd(부팅 후반)로 이동 |
