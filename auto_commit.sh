#!/bin/bash

# 자동 Git 커밋 스크립트
echo "🔄 자동 Git 커밋 시작..."

# 현재 시간으로 커밋 메시지 생성
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
COMMIT_MSG="Auto commit: $TIMESTAMP - ProteinLibrary.swift 수정"

# 수정된 파일들 추가
git add Sources/App/ProteinLibrary.swift

# 커밋
git commit -m "$COMMIT_MSG"

echo "✅ 자동 커밋 완료: $COMMIT_MSG"
echo "📝 Git 상태:"
git status --short
