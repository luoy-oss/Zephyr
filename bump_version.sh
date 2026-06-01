#!/bin/bash
# 版本号更新脚本
# 用法: ./bump_version.sh <版本号>
# 示例: ./bump_version.sh 1.0.0-beta.15
#        ./bump_version.sh 1.0.0

set -e

if [ -z "$1" ]; then
    echo "用法: $0 <版本号>"
    echo "示例: $0 1.0.0-beta.15"
    echo "      $0 1.0.0"
    exit 1
fi

VERSION="$1"

# 从版本号中提取版本代码（去掉前缀v如果有的话）
VERSION_CLEAN="${VERSION#v}"

# 提取数字部分作为 versionCode（去掉所有非数字字符，用+号分隔）
# 例如: 1.0.0-beta.14 → 14, 1.0.0 → 1
# 简单策略：用最后的数字作为 versionCode
if [[ "$VERSION_CLEAN" =~ ([0-9]+)$ ]]; then
    VERSION_CODE="${BASH_REMATCH[1]}"
else
    VERSION_CODE="1"
fi

echo "版本号: $VERSION_CLEAN"
echo "版本代码: $VERSION_CODE"

# 更新 pubspec.yaml
sed -i "s/^version: .*/version: $VERSION_CLEAN+$VERSION_CODE/" pubspec.yaml

echo ""
echo "已更新 pubspec.yaml: version: $VERSION_CLEAN+$VERSION_CODE"
echo ""
echo "下一步:"
echo "  git add pubspec.yaml"
echo "  git commit -m \"chore: bump version to $VERSION_CLEAN\""
echo "  git tag v$VERSION_CLEAN"
echo "  git push origin main && git push origin v$VERSION_CLEAN"
