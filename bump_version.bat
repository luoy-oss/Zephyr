@echo off
REM 版本号更新脚本 (Windows)
REM 用法: bump_version.bat <版本号>
REM 示例: bump_version.bat 1.0.0-beta.15
REM        bump_version.bat 1.0.0

if "%~1"=="" (
    echo 用法: %0 ^<版本号^>
    echo 示例: %0 1.0.0-beta.15
    echo       %0 1.0.0
    exit /b 1
)

set "VERSION=%~1"

REM 使用 PowerShell 处理正则替换
powershell -Command "
    $version = '%VERSION%'
    $versionClean = $version -replace '^v', ''
    if ($versionClean -match '(\d+)$') {
        $versionCode = $matches[1]
    } else {
        $versionCode = '1'
    }
    Write-Host \"版本号: $versionClean\"
    Write-Host \"版本代码: $versionCode\"
    $content = Get-Content pubspec.yaml -Raw
    $content = $content -replace 'version: .+', \"version: $versionClean+$versionCode\"
    Set-Content pubspec.yaml $content -NoNewline
    Write-Host ''
    Write-Host \"已更新 pubspec.yaml: version: $versionClean+$versionCode\"
"

echo.
echo 下一步:
echo   git add pubspec.yaml
echo   git commit -m "chore: bump version to %VERSION%"
echo   git tag v%VERSION%
echo   git push origin main ^&^& git push origin v%VERSION%
