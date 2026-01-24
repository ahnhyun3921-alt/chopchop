#!/usr/bin/env python3
"""
Firebase 참조가 없는 완전히 새로운 Xcode 프로젝트 파일 생성
"""

import uuid
import sys

def generate_uuid():
    """Xcode 스타일의 24자리 UUID 생성"""
    return uuid.uuid4().hex[:24].upper()

# 모든 Swift 파일 정의
files = {
    'Models': ['Restaurant.swift'],
    'Views': ['FavoritesView.swift', 'LoginView.swift', 'MainTabView.swift', 'NaverMapView.swift',
              'PersonManagementView.swift', 'RestaurantDetailView.swift', 'RestaurantSearchView.swift',
              'SignInWithAppleButton.swift'],
    'ViewModels': ['FavoritesViewModel.swift', 'PersonManagementViewModel.swift', 'RestaurantDetailViewModel.swift'],
    'Services': ['AuthenticationService.swift', 'ClaudeAPIService.swift', 'Config.swift',
                 'FirestoreService.swift', 'KakaoLocalService.swift', 'MenuAnalysisService.swift',
                 'NaverSearchService.swift'],
    'Utils': ['ColorExtension.swift'],
    'App': ['SafeEatApp.swift']
}

# UUID 생성
project_uuid = generate_uuid()
target_uuid = generate_uuid()
build_phase_sources_uuid = generate_uuid()
build_phase_frameworks_uuid = generate_uuid()
build_phase_resources_uuid = generate_uuid()
product_ref_uuid = generate_uuid()
main_group_uuid = generate_uuid()
products_group_uuid = generate_uuid()

# 그룹 UUID
group_uuids = {group: generate_uuid() for group in files.keys()}

# 파일 UUID 생성
file_refs = {}
build_files = {}

for group, file_list in files.items():
    for filename in file_list:
        file_refs[filename] = generate_uuid()
        build_files[filename] = generate_uuid()

# Assets UUID
assets_ref_uuid = generate_uuid()
assets_build_uuid = generate_uuid()

print("🚀 완전히 새로운 Xcode 프로젝트 파일 생성 중...")

project_content = f"""// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{
\t}};
\tobjectVersion = 56;
\tobjects = {{

/* Begin PBXBuildFile section */
"""

# Build Files 추가
for group, file_list in files.items():
    for filename in file_list:
        project_content += f"\t\t{build_files[filename]} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs[filename]} /* {filename} */; }};\n"

project_content += f"\t\t{assets_build_uuid} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {assets_ref_uuid} /* Assets.xcassets */; }};\n"

project_content += f"""/* End PBXBuildFile section */

/* Begin PBXFileReference section */
"""

# File References 추가
for group, file_list in files.items():
    for filename in file_list:
        path = f"{group}/{filename}" if group != 'App' else filename
        project_content += f"\t\t{file_refs[filename]} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};\n"

project_content += f"\t\t{product_ref_uuid} /* SafeEat.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = SafeEat.app; sourceTree = BUILT_PRODUCTS_DIR; }};\n"
project_content += f"\t\t{assets_ref_uuid} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; }};\n"

project_content += f"""/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
\t\t{build_phase_frameworks_uuid} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
"""

# 그룹 추가
for group, file_list in files.items():
    project_content += f"\t\t{group_uuids[group]} /* {group} */ = {{\n"
    project_content += f"\t\t\tisa = PBXGroup;\n"
    project_content += f"\t\t\tchildren = (\n"
    for filename in file_list:
        project_content += f"\t\t\t\t{file_refs[filename]} /* {filename} */,\n"
    project_content += f"\t\t\t);\n"
    project_content += f"\t\t\tpath = {group if group != 'App' else 'SafeEat'};\n"
    project_content += f"\t\t\tsourceTree = \"<group>\";\n"
    project_content += f"\t\t}};\n"

# SafeEat 폴더 그룹
safeat_folder_uuid = generate_uuid()
project_content += f"\t\t{safeat_folder_uuid} /* SafeEat */ = {{\n"
project_content += f"\t\t\tisa = PBXGroup;\n"
project_content += f"\t\t\tchildren = (\n"
project_content += f"\t\t\t\t{file_refs['SafeEatApp.swift']} /* SafeEatApp.swift */,\n"
project_content += f"\t\t\t\t{group_uuids['Views']} /* Views */,\n"
project_content += f"\t\t\t\t{group_uuids['ViewModels']} /* ViewModels */,\n"
project_content += f"\t\t\t\t{group_uuids['Models']} /* Models */,\n"
project_content += f"\t\t\t\t{group_uuids['Services']} /* Services */,\n"
project_content += f"\t\t\t\t{group_uuids['Utils']} /* Utils */,\n"
project_content += f"\t\t\t\t{assets_ref_uuid} /* Assets.xcassets */,\n"
project_content += f"\t\t\t);\n"
project_content += f"\t\t\tpath = SafeEat;\n"
project_content += f"\t\t\tsourceTree = \"<group>\";\n"
project_content += f"\t\t}};\n"

# Products 그룹
project_content += f"\t\t{products_group_uuid} /* Products */ = {{\n"
project_content += f"\t\t\tisa = PBXGroup;\n"
project_content += f"\t\t\tchildren = (\n"
project_content += f"\t\t\t\t{product_ref_uuid} /* SafeEat.app */,\n"
project_content += f"\t\t\t);\n"
project_content += f"\t\t\tname = Products;\n"
project_content += f"\t\t\tsourceTree = \"<group>\";\n"
project_content += f"\t\t}};\n"

# Root 그룹
project_content += f"\t\t{main_group_uuid} = {{\n"
project_content += f"\t\t\tisa = PBXGroup;\n"
project_content += f"\t\t\tchildren = (\n"
project_content += f"\t\t\t\t{safeat_folder_uuid} /* SafeEat */,\n"
project_content += f"\t\t\t\t{products_group_uuid} /* Products */,\n"
project_content += f"\t\t\t);\n"
project_content += f"\t\t\tsourceTree = \"<group>\";\n"
project_content += f"\t\t}};\n"

project_content += f"""/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t{target_uuid} /* SafeEat */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {generate_uuid()} /* Build configuration list for PBXNativeTarget "SafeEat" */;
\t\t\tbuildPhases = (
\t\t\t\t{build_phase_sources_uuid} /* Sources */,
\t\t\t\t{build_phase_frameworks_uuid} /* Frameworks */,
\t\t\t\t{build_phase_resources_uuid} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = SafeEat;
\t\t\tproductName = SafeEat;
\t\t\tproductReference = {product_ref_uuid} /* SafeEat.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t{project_uuid} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1500;
\t\t\t\tLastUpgradeCheck = 1500;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{target_uuid} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {generate_uuid()} /* Build configuration list for PBXProject "SafeEat" */;
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {main_group_uuid};
\t\t\tproductRefGroup = {products_group_uuid} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{target_uuid} /* SafeEat */,
\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t{build_phase_resources_uuid} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{assets_build_uuid} /* Assets.xcassets in Resources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
\t\t{build_phase_sources_uuid} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
"""

# Sources 빌드 파일 추가
for group, file_list in files.items():
    for filename in file_list:
        project_content += f"\t\t\t\t{build_files[filename]} /* {filename} in Sources */,\n"

project_content += f"""\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
\t\t{generate_uuid()} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 14.0;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{generate_uuid()} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tENABLE_NS_ASSERTIONS = NO;
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 14.0;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tVALIDATE_PRODUCT = YES;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{generate_uuid()} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASS ETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_TEAM = "";
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
\t\t\t\tINFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;
\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.safeeat.app;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{generate_uuid()} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_TEAM = "";
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
\t\t\t\tINFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;
\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.safeeat.app;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Release;
\t\t}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t{generate_uuid()} /* Build configuration list for PBXProject "SafeEat" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{generate_uuid()} /* Debug */,
\t\t\t\t{generate_uuid()} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{generate_uuid()} /* Build configuration list for PBXNativeTarget "SafeEat" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{generate_uuid()} /* Debug */,
\t\t\t\t{generate_uuid()} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
/* End XCConfigurationList section */
\t}};
\trootObject = {project_uuid} /* Project object */;
}}
"""

# 파일 저장
with open('SafeEat.xcodeproj/project.pbxproj', 'w', encoding='utf-8') as f:
    f.write(project_content)

print("✅ 완전히 새로운 Xcode 프로젝트 파일 생성 완료!")
print("✅ Firebase 참조가 전혀 없는 깨끗한 프로젝트입니다!")
print("\n다음 단계:")
print("1. Xcode 닫기 (Command + Q)")
print("2. Xcode 다시 열기: open SafeEat.xcodeproj")
print("3. 빌드 (Command + B)")
