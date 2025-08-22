#!/bin/bash

# 파일 변경 감지 및 자동 Git 커밋 스크립트
echo "👀 ProteinLibrary.swift 파일 변경 감지 시작..."
echo "📁 감시 중인 파일: Sources/App/ProteinLibrary.swift"
echo "🔄 변경 시 자동 커밋됩니다..."

# 파일 변경 감지 및 자동 커밋
fswatch -o Sources/App/ProteinLibrary.swift | while read f; do
    echo "🔄 파일 변경 감지됨! 자동 커밋 시작..."
    
    # 잠시 대기 (파일 쓰기 완료 대기)
    sleep 2
    
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
    echo "👀 계속 감시 중..."
done
