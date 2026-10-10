@echo off
set DIR=%~dp0
if not exist "%DIR%gradle\wrapper\gradle-wrapper.jar" (
 echo Run scripts\bootstrap_android.ps1 with Flutter installed.
 exit /b 1
)
if defined JAVA_HOME (set JAVAEXE=%JAVA_HOME%\bin\java.exe) else (set JAVAEXE=java.exe)
"%JAVAEXE%" -classpath "%DIR%gradle\wrapper\gradle-wrapper.jar" org.gradle.wrapper.GradleWrapperMain %*
