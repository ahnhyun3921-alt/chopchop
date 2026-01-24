#!/usr/bin/env python3
"""
Xcode 프로젝트에 새로운 파일들을 자동으로 추가하는 스크립트
"""

import sys
import uuid
import re
from pathlib import Path

# 추가할 파일들 정의
FILES_TO_ADD = [
    {
        'path': 'SafeEat/SafeEat/Views/FavoritesView.swift',
        'group': 'Views',
        'build_phase': True
    },
    {
        'path': 'SafeEat/SafeEat/ViewModels/FavoritesViewModel.swift',
        'group': 'ViewModels',
        'build_phase': True
    },
    {
        'path': 'SafeEat/SafeEat/Services/KakaoLocalService.swift',
        'group': 'Services',
        'build_phase': True
    }
]

def generate_uuid():
    """Xcode 스타일의 24자리 UUID 생성"""
    return uuid.uuid4().hex[:24].upper()

def add_files_to_xcode_project():
    project_file = Path('SafeEat/SafeEat.xcodeproj/project.pbxproj')

    if not project_file.exists():
        print(f"❌ 프로젝트 파일을 찾을 수 없습니다: {project_file}")
        return False

    print("🚀 Xcode 프로젝트 자동 설정 시작...\n")

    # 프로젝트 파일 읽기
    print("📁 Xcode 프로젝트 파일 읽는 중...")
    with open(project_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # 백업 생성
    backup_file = project_file.with_suffix('.pbxproj.backup2')
    with open(backup_file, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"✅ 백업 생성 완료: {backup_file}\n")

    # 각 파일 처리
    for file_info in FILES_TO_ADD:
        file_path = Path(file_info['path'])

        # 파일이 실제로 존재하는지 확인
        if not file_path.exists():
            print(f"⚠️  파일이 존재하지 않음 (건너뜀): {file_path}")
            continue

        file_name = file_path.name

        # 이미 프로젝트에 추가되어 있는지 확인
        if file_name in content:
            print(f"⏭️  이미 추가됨 (건너뜀): {file_name}")
            continue

        print(f"🔨 추가 중: {file_name}")

        # UUID 생성
        file_ref_id = generate_uuid()
        build_file_id = generate_uuid()

        # 1. PBXFileReference 추가
        file_ref_section = re.search(r'/\* Begin PBXFileReference section \*/', content)
        if file_ref_section:
            file_ref_entry = f"\t\t{file_ref_id} /* {file_name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {file_name}; sourceTree = \"<group>\"; }};\n"
            insert_pos = file_ref_section.end()
            content = content[:insert_pos] + '\n' + file_ref_entry + content[insert_pos:]
            print(f"  ✓ PBXFileReference 추가")

        # 2. PBXBuildFile 추가 (빌드 페이즈에 포함되는 경우)
        if file_info['build_phase']:
            build_file_section = re.search(r'/\* Begin PBXBuildFile section \*/', content)
            if build_file_section:
                build_file_entry = f"\t\t{build_file_id} /* {file_name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* {file_name} */; }};\n"
                insert_pos = build_file_section.end()
                content = content[:insert_pos] + '\n' + build_file_entry + content[insert_pos:]
                print(f"  ✓ PBXBuildFile 추가")

        # 3. PBXGroup에 추가 (그룹별)
        group_name = file_info['group']
        group_pattern = rf'/\* {group_name} \*/.*?children = \(\s*'
        group_match = re.search(group_pattern, content, re.DOTALL)
        if group_match:
            group_entry = f"\t\t\t\t{file_ref_id} /* {file_name} */,\n"
            insert_pos = group_match.end()
            content = content[:insert_pos] + group_entry + content[insert_pos:]
            print(f"  ✓ {group_name} 그룹에 추가")

        # 4. PBXSourcesBuildPhase에 추가
        if file_info['build_phase']:
            sources_build_pattern = r'/\* Sources \*/.*?files = \(\s*'
            sources_match = re.search(sources_build_pattern, content, re.DOTALL)
            if sources_match:
                sources_entry = f"\t\t\t\t{build_file_id} /* {file_name} in Sources */,\n"
                insert_pos = sources_match.end()
                content = content[:insert_pos] + sources_entry + content[insert_pos:]
                print(f"  ✓ Sources 빌드 페이즈에 추가")

        print(f"✅ {file_name} 추가 완료\n")

    # 프로젝트 파일 저장
    print("💾 프로젝트 파일 저장 중...")
    with open(project_file, 'w', encoding='utf-8') as f:
        f.write(content)

    print("\n" + "="*60)
    print("✅ Xcode 프로젝트 업데이트 완료!")
    print("="*60)
    print("\n다음 단계:")
    print("1. Xcode 닫기 (열려있다면)")
    print("2. Xcode 다시 열기")
    print("3. Command + B로 빌드 확인")

    return True

if __name__ == '__main__':
    try:
        success = add_files_to_xcode_project()
        sys.exit(0 if success else 1)
    except Exception as e:
        print(f"\n❌ 오류 발생: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
