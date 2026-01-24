#!/usr/bin/env python3
"""
MainTabView.swift를 Xcode 프로젝트에 추가하는 스크립트
"""

import sys
import uuid
import re
from pathlib import Path

def generate_uuid():
    """Xcode 스타일의 24자리 UUID 생성"""
    return uuid.uuid4().hex[:24].upper()

def add_maintabview_to_project():
    project_file = Path('SafeEat.xcodeproj/project.pbxproj')

    if not project_file.exists():
        print(f"❌ 프로젝트 파일을 찾을 수 없습니다: {project_file}")
        return False

    print("🚀 MainTabView.swift를 Xcode 프로젝트에 추가 중...\n")

    # 프로젝트 파일 읽기
    with open(project_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # 백업 생성
    backup_file = project_file.with_suffix('.pbxproj.backup3')
    with open(backup_file, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"✅ 백업 생성: {backup_file}\n")

    file_name = "MainTabView.swift"

    # 이미 추가되어 있는지 확인
    if file_name in content:
        print(f"⏭️  {file_name}은(는) 이미 프로젝트에 있습니다.")
        return True

    # UUID 생성
    file_ref_id = generate_uuid()
    build_file_id = generate_uuid()

    print(f"📝 {file_name} 추가 중...")

    # 1. PBXFileReference 추가
    file_ref_section = re.search(r'/\* Begin PBXFileReference section \*/', content)
    if file_ref_section:
        file_ref_entry = f"\t\t{file_ref_id} /* {file_name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {file_name}; sourceTree = \"<group>\"; }};\n"
        insert_pos = file_ref_section.end()
        content = content[:insert_pos] + '\n' + file_ref_entry + content[insert_pos:]
        print(f"  ✓ PBXFileReference 추가")

    # 2. PBXBuildFile 추가
    build_file_section = re.search(r'/\* Begin PBXBuildFile section \*/', content)
    if build_file_section:
        build_file_entry = f"\t\t{build_file_id} /* {file_name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* {file_name} */; }};\n"
        insert_pos = build_file_section.end()
        content = content[:insert_pos] + '\n' + build_file_entry + content[insert_pos:]
        print(f"  ✓ PBXBuildFile 추가")

    # 3. Views 그룹에 추가
    views_group_pattern = r'/\* Views \*/.*?children = \(\s*'
    views_match = re.search(views_group_pattern, content, re.DOTALL)
    if views_match:
        group_entry = f"\t\t\t\t{file_ref_id} /* {file_name} */,\n"
        insert_pos = views_match.end()
        content = content[:insert_pos] + group_entry + content[insert_pos:]
        print(f"  ✓ Views 그룹에 추가")

    # 4. PBXSourcesBuildPhase에 추가
    sources_build_pattern = r'/\* Sources \*/.*?files = \(\s*'
    sources_match = re.search(sources_build_pattern, content, re.DOTALL)
    if sources_match:
        sources_entry = f"\t\t\t\t{build_file_id} /* {file_name} in Sources */,\n"
        insert_pos = sources_match.end()
        content = content[:insert_pos] + sources_entry + content[insert_pos:]
        print(f"  ✓ Sources 빌드 페이즈에 추가")

    # 프로젝트 파일 저장
    print("\n💾 프로젝트 파일 저장 중...")
    with open(project_file, 'w', encoding='utf-8') as f:
        f.write(content)

    print("\n" + "="*60)
    print("✅ MainTabView.swift 추가 완료!")
    print("="*60)
    print("\n다음 단계:")
    print("1. Xcode 닫기 (Command + Q)")
    print("2. Xcode 다시 열기")
    print("3. Product > Clean Build Folder (Shift + Command + K)")
    print("4. 빌드 (Command + B)")

    return True

if __name__ == '__main__':
    try:
        success = add_maintabview_to_project()
        sys.exit(0 if success else 1)
    except Exception as e:
        print(f"\n❌ 오류 발생: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
