#!/bin/bash
# Lu (LukuApp) 설치 스크립트
# 사용: bash <(curl -s https://raw.githubusercontent.com/lukuku-dev/lukuku-config/main/install.sh)
set -e

echo "🎙 Lu 설치 시작..."
echo ""

# 1. Xcode CLI Tools
if ! xcode-select -p &>/dev/null; then
    echo "[1/6] Xcode CLI Tools 설치중..."
    xcode-select --install
    echo "Xcode CLI Tools 설치 완료 후 이 스크립트를 다시 실행해주세요."
    exit 0
else
    echo "[1/6] Xcode CLI Tools ✓"
fi

# 2. GitHub CLI 확인
if ! which gh &>/dev/null; then
    echo "[2/6] GitHub CLI 설치중..."
    if which brew &>/dev/null; then
        brew install gh
    else
        echo "Homebrew가 없습니다. 먼저 설치해주세요:"
        echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        exit 1
    fi
else
    echo "[2/6] GitHub CLI ✓"
fi

# 3. GitHub 로그인 확인
if ! gh auth status &>/dev/null 2>&1; then
    echo "[2/6] GitHub 로그인 필요..."
    gh auth login
fi

# 4. 레포 clone + 빌드
APPS_DIR="$HOME/project/lukuku-apps"
if [ -d "$APPS_DIR/LukuApp" ]; then
    echo "[3/6] 기존 설치 발견 — 업데이트..."
    cd "$APPS_DIR" && git pull
else
    echo "[3/6] 레포 clone..."
    mkdir -p "$HOME/project"
    cd "$HOME/project"
    gh repo clone lukuku-dev/lukuku-apps
fi

echo "[4/6] 빌드중..."
cd "$APPS_DIR/LukuApp"
swift build 2>&1 | tail -1

# 5. .app 번들 생성 + codesign
echo "[5/6] 앱 설치중..."
APP="/Applications/LukuApp.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/debug/LukuApp "$APP/Contents/MacOS/"
cp Sources/Info.plist "$APP/Contents/"

# self-signed cert 생성 (없으면)
if ! security find-identity -v -p codesigning 2>/dev/null | grep -q "LukuDev"; then
    echo "  코드 서명 인증서 생성중..."
    cat > /tmp/lukudev_cert.cfg << 'CERTEOF'
[ req ]
default_bits = 2048
distinguished_name = req_dn
prompt = no
[ req_dn ]
CN = LukuDev
[ v3_code_sign ]
keyUsage = digitalSignature
extendedKeyUsage = codeSigning
CERTEOF
    openssl req -x509 -newkey rsa:2048 -keyout /tmp/lukudev.key -out /tmp/lukudev.pem -days 3650 -nodes -config /tmp/lukudev_cert.cfg -extensions v3_code_sign 2>/dev/null
    security import /tmp/lukudev.pem -k ~/Library/Keychains/login.keychain-db -t cert 2>/dev/null
    security import /tmp/lukudev.key -k ~/Library/Keychains/login.keychain-db -t priv 2>/dev/null
    security add-trusted-cert -d -r trustRoot -k ~/Library/Keychains/login.keychain-db /tmp/lukudev.pem 2>/dev/null
    rm /tmp/lukudev.key /tmp/lukudev.pem /tmp/lukudev_cert.cfg 2>/dev/null
fi

codesign --force --sign "LukuDev" --identifier co.lukuku.LukuApp "$APP" 2>/dev/null

# 6. CLAUDE.md에 Lu 추가
echo "[6/6] Claude Code 설정..."
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
mkdir -p "$HOME/.claude"
if [ ! -f "$CLAUDE_MD" ]; then
    touch "$CLAUDE_MD"
fi

if ! grep -q "Lu (녹음앱)" "$CLAUDE_MD" 2>/dev/null; then
    cat >> "$CLAUDE_MD" << 'CLAUDEEOF'

# Lu (녹음앱)
- 사용법: `curl -s localhost:699/help 2>/dev/null` — 앱이 켜져 있으면 최신 가이드 반환
- 앱 안 켜져 있으면: `open /Applications/LukuApp.app` 또는 설치 필요
- 설치: `bash <(curl -s https://raw.githubusercontent.com/lukuku-dev/lukuku-config/main/install.sh)`
- "회의 정리해줘", "녹음 올려줘" 등 요청 시 먼저 `curl localhost:699/help`로 사용법 확인 후 처리
CLAUDEEOF
    echo "  CLAUDE.md에 Lu 추가 ✓"
else
    echo "  CLAUDE.md 이미 설정됨 ✓"
fi

# 앱 실행
echo ""
echo "🎙 Lu 설치 완료!"
echo ""
echo "앱을 실행합니다..."
open "$APP"
echo ""
echo "⚠️  시스템 설정 > 개인정보 > 화면 및 시스템 오디오 녹음에서 LukuApp을 허용해주세요."
echo ""
echo "사용법:"
echo "  - 메뉴바에 🎙 Lu 표시 → 녹음 중"
echo "  - Claude Code에서: \"회의 정리해줘\", \"녹음 올려줘\""
echo "  - API: curl localhost:699/status"
