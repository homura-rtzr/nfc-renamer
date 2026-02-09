# NfcRenamer

Windows Explorer 컨텍스트 메뉴에서 파일/폴더 이름을 **Unicode NFC**(Normalization Form C)로 정규화하는 유틸리티입니다.

macOS에서 생성된 파일을 Windows로 복사하면 한글 파일명이 NFD(자모 분리) 형태로 저장되어 검색이 안 되거나 깨져 보이는 문제가 발생합니다. NfcRenamer는 이런 파일명을 NFC로 변환하여 정상적으로 표시되도록 합니다.

## 설치

### GitHub Release에서 다운로드

1. [Releases](../../releases) 페이지에서 아키텍처에 맞는 ZIP 다운로드 (`win-x64` 또는 `win-arm64`)
2. 원하는 위치에 압축 해제
3. `NfcRenamer.exe` 실행 경로를 기억해 두기

### 소스에서 빌드 및 설치

.NET 9 SDK (Windows desktop workload 포함)가 필요합니다.

```powershell
git clone https://github.com/homura-rtzr/nfc-renamer.git
cd nfc-renamer
powershell -ExecutionPolicy Bypass -File install.ps1
```

`install.ps1`이 자동으로 수행하는 작업:
- `dotnet publish`로 self-contained 빌드
- `%LOCALAPPDATA%\NfcRenamer\`에 바이너리 복사
- HKCU 레지스트리에 Explorer 컨텍스트 메뉴 등록 (관리자 권한 불필요)

## 사용법

설치 후 파일이나 폴더를 우클릭하면 컨텍스트 메뉴에 다음 항목이 나타납니다:

| 메뉴 | 동작 |
|------|------|
| **NFC 정규화** | 선택한 파일/폴더 이름을 NFC로 변환 |
| **NFC 정규화 (하위 포함)** | 폴더 내 모든 하위 파일/폴더까지 재귀적으로 변환 |

> Windows 11에서는 **"더 많은 옵션 표시"** 를 먼저 클릭해야 메뉴가 보입니다.

여러 파일을 동시에 선택하여 실행할 수 있습니다.

## 제거

```powershell
powershell -ExecutionPolicy Bypass -File uninstall.ps1
```

컨텍스트 메뉴 레지스트리 키와 설치 디렉터리를 삭제합니다.

## 로그

동작 로그는 `%LOCALAPPDATA%\NfcRenamer\log.txt`에 기록됩니다.

## 라이선스

MIT
