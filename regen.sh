#!/bin/bash
# 重新生成 Inspirations.xcodeproj
# 新增/删除源码文件后需要运行本脚本（工程文件由 project.yml 生成）
cd "$(dirname "$0")"
.tools/xcodegen.artifactbundle/xcodegen-2.46.0-macosx/bin/xcodegen generate
