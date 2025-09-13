# PROTEIN_VIEWER_SPEC.md
절대 기존 기능을 없애지 말것, 없앨 경우 승인 받고 할것
build 할때 platform 은 macOS로 할것
소스 작성시 구조체 소스 수정 시 열고 닫는 위치를 확인 후 수정할것
교육용 **Protein Viewer** 앱을 “네이티브 Swift만으로” 자동 개발(Copilot/Cursor Auto)하기 위한 **단일 설계 문서**입니다.  
목표: 백엔드 없이도 PDB/AlphaFold 공개 리소스에서 직접 구조를 내려받아 **1–4차 구조 단계별 시각화 + 학습 기능**을 제공합니다.

---

## 0. 디자인 결정(의견)
- **렌더링**: SceneKit 기반(추후 Metal로 확장). 1차 릴리스에서는 **Cartoon/Stick/Sphere** 중심. 표면(SES)·전하맵은 2차 로드맵.
- **데이터 소스(백엔드 없음)**:  
  - RCSB PDB mmCIF: `https://files.rcsb.org/download/{PDB_ID}.cif`  
  - AlphaFold mmCIF(선택)  
- **결합 정보**: 거리 기반(공유결합 반경 표)로 온디바이스 생성.  
- **교육성 강화**: “설명 모드/퀴즈/툴팁/서열↔구조 연동”을 필수로 포함.  
- **성능**: 큰 구조(>50k atoms)는 **Cartoon 전용 + LOD** 기본.

---

## 1. 범위
### 1.1 기능(요구 사항)
- **기본 뷰어**
  - 회전/확대/축소, 슬라이스(Clipping Plane 1개)
  - 표현: Spheres, Sticks, Cartoon
  - 색상: Element, Chain, Uniform, SecondaryStructure
  - **구조 단계별 보기**: 1차(서열), 2차(α/β/loop), 3차(접힘), 4차(조립체)
- **학습 지원**
  - 설명 모드(초·중·고 / 대학·전문가 2레벨)
  - 퀴즈(객관식/주관식) + 피드백
  - 하이라이트: 활성 부위/리간드/도메인(간단 예시 데이터 내장)
  - 질병 관련 변이 포인트(샘플)
- **생물학적 맥락**
  - 대표 단백질 5종(헤모글로빈/인슐린 등) 카드 + 요약
- **최신 데이터 연동**
  - PDB ID 직접 입력/검색(간단 필드) → mmCIF 다운로드/캐시
- **확장**
  - AR 모드(선택, RealityKit로 표면/카툰 노드 배치)
  - 다국어(영/한 우선), 학습 진도 로컬 저장

### 1.2 비범위(1차 릴리스에서 제외)
- 신약개발용 정밀 전하맵, SES 실시간 생성, 서버 사이드 전처리
- 교사용 대시보드/클라우드 동기화

---

## 2. 화면/플로우
### 2.1 네비게이션
- **HomeView** → **ViewerView** → (InfoSheet / QuizSheet)
- **SearchSheet**: PDB ID 입력 → 다운로드 → ViewerView 로드

### 2.2 주요 화면 구성
- **ViewerView**
  - 상단: 제목(Protein Viewer), “+”(불러오기), “i”(정보)
  - 중앙: **SCNView**(SceneKit)
  - 우측 부동 버튼: ▶︎(단계별 재생), ⓘ(설명 모드)
  - 하단 **ControlBar**(8개 버튼): Spheres / Sticks / Cartoon / Slice / Element / Chain / Uniform / Secondary Structure
  - **SequenceBar**(토글): 1차 서열 스크럽 → 구조 하이라이트
- **InfoSheet**
  - 단백질명, 기능 요약, PDB 링크, 간단 질병 연관성
- **QuizSheet**
  - 문제 → 답 선택 → 정답 하이라이트, 해설
