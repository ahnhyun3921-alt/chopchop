#!/usr/bin/env python3
"""
Xcode 프로젝트에 Services 폴더의 모든 파일을 자동으로 추가하는 스크립트
"""

import os
import uuid
import re

# 경로 설정
PROJECT_FILE = '/home/user/chopchop/SafeEat/SafeEat.xcodeproj/project.pbxproj'
SERVICES_DIR = '/home/user/chopchop/SafeEat/SafeEat/Services'

# Services 폴더의 모든 Swift 파일 가져오기
service_files = [
    'AuthenticationService.swift',
    'ClaudeAPIService.swift',
    'Config.swift',
    'FirestoreService.swift',
    'MenuAnalysisService.swift',
    'NaverSearchService.swift'
]

def generate_uuid():
    """Xcode 스타일의 24자 UUID 생성"""
    return uuid.uuid4().hex[:24].upper()

def add_files_to_xcode():
    """Xcode 프로젝트 파일에 Services 파일들 추가"""

    print("📁 Xcode 프로젝트 파일 읽는 중...")
    with open(PROJECT_FILE, 'r', encoding='utf-8') as f:
        content = f.read()

    # UUID 생성
    file_refs = {}
    build_files = {}

    for filename in service_files:
        file_refs[filename] = generate_uuid()
        build_files[filename] = generate_uuid()

    services_group_uuid = generate_uuid()

    print("🔨 파일 참조 추가 중...")

    # PBXFileReference 섹션에 파일 추가
    file_reference_section = "/* Begin PBXFileReference section */"
    file_ref_index = content.find(file_reference_section)

    if file_ref_index == -1:
        print("❌ PBXFileReference 섹션을 찾을 수 없습니다.")
        return False

    # 삽입할 위치 찾기 (섹션 시작 후 첫 줄)
    insert_pos = content.find('\n', file_ref_index) + 1

    # 파일 참조 생성
    file_references = []
    for filename in service_files:
        ref = f"\t\t{file_refs[filename]} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};\n"
        file_references.append(ref)

    # 파일 참조 삽입
    content = content[:insert_pos] + ''.join(file_references) + content[insert_pos:]

    print("📦 빌드 파일 추가 중...")

    # PBXBuildFile 섹션에 추가
    build_file_section = "/* Begin PBXBuildFile section */"
    build_file_index = content.find(build_file_section)

    if build_file_index == -1:
        print("❌ PBXBuildFile 섹션을 찾을 수 없습니다.")
        return False

    insert_pos = content.find('\n', build_file_index) + 1

    # 빌드 파일 생성
    build_file_entries = []
    for filename in service_files:
        entry = f"\t\t{build_files[filename]} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs[filename]} /* {filename} */; }};\n"
        build_file_entries.append(entry)

    # 빌드 파일 삽입
    content = content[:insert_pos] + ''.join(build_file_entries) + content[insert_pos:]

    print("📂 Services 그룹 추가 중...")

    # PBXGroup에서 SafeEat 그룹 찾기
    group_section = "/* Begin PBXGroup section */"
    group_index = content.find(group_section)

    if group_index == -1:
        print("❌ PBXGroup 섹션을 찾을 수 없습니다.")
        return False

    # SafeEat 그룹 찾기 (children에 추가할 것)
    # Utils 그룹이 있는 SafeEat 그룹 찾기
    safeeat_group_pattern = r'(/\* SafeEat \*/[^}]+children = \([^)]+)'
    match = re.search(safeeat_group_pattern, content)

    if match:
        # children 배열 끝에 Services 그룹 참조 추가
        insert_text = f"\n\t\t\t\t{services_group_uuid} /* Services */,"
        insert_position = match.end()
        content = content[:insert_position] + insert_text + content[insert_position:]

    # Services 그룹 정의 추가
    insert_pos = content.find('\n', group_index) + 1

    children_refs = ',\n'.join([f"\t\t\t\t{file_refs[f]} /* {f} */" for f in service_files])

    services_group = f"""\t\t{services_group_uuid} /* Services */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{children_refs},
\t\t\t);
\t\t\tpath = Services;
\t\t\tsourceTree = "<group>";
\t\t}};
"""

    content = content[:insert_pos] + services_group + content[insert_pos:]

    print("🔧 소스 빌드 페이즈에 추가 중...")

    # PBXSourcesBuildPhase에 파일 추가
    sources_phase_pattern = r'(PBXSourcesBuildPhase[^}]+files = \([^)]+)'
    match = re.search(sources_phase_pattern, content)

    if match:
        source_refs = ',\n'.join([f"\t\t\t\t{build_files[f]} /* {f} in Sources */" for f in service_files])
        insert_text = f"\n{source_refs},"
        insert_position = match.end()
        content = content[:insert_position] + insert_text + content[insert_position:]

    print("💾 프로젝트 파일 저장 중...")

    # 백업 생성
    backup_file = PROJECT_FILE + '.backup'
    with open(backup_file, 'w', encoding='utf-8') as f:
        # 원본 파일 읽기
        with open(PROJECT_FILE, 'r', encoding='utf-8') as orig:
            f.write(orig.read())
    print(f"✅ 백업 생성 완료: {backup_file}")

    # 수정된 내용 저장
    with open(PROJECT_FILE, 'w', encoding='utf-8') as f:
        f.write(content)

    print("✅ Xcode 프로젝트에 Services 파일들이 추가되었습니다!")
    print("\n📋 추가된 파일:")
    for filename in service_files:
        print(f"  - {filename}")

    return True

if __name__ == '__main__':
    print("🚀 Xcode 프로젝트 자동 설정 시작...\n")

    if os.path.exists(PROJECT_FILE):
        success = add_files_to_xcode()

        if success:
            print("\n🎉 완료! Xcode를 다시 열면 Services 폴더가 보입니다!")
            print("\n다음 단계:")
            print("1. Xcode 닫기 (열려있다면)")
            print("2. Xcode 다시 열기")
            print("3. Command + B로 빌드 확인")
        else:
            print("\n❌ 오류가 발생했습니다.")
            print("백업 파일로 복구하려면:")
            print(f"mv {PROJECT_FILE}.backup {PROJECT_FILE}")
    else:
        print(f"❌ 프로젝트 파일을 찾을 수 없습니다: {PROJECT_FILE}")
