$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$tmp = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
try {
 flutter create --platforms=android --org com.upc --project-name upc "$tmp/template"
 if ($LASTEXITCODE -ne 0) { throw "Flutter template creation failed" }
 Copy-Item "$tmp/template/android/gradle/wrapper/gradle-wrapper.jar" "$root/android/gradle/wrapper/gradle-wrapper.jar"
 Copy-Item "$tmp/template/android/gradlew*" "$root/android/"
} finally { Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue }
