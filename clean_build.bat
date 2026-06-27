@echo off
setlocal
echo =========================================
echo Schone Build GGIHolland APK
echo =========================================

set PROJECT_DIR=%~dp0
set TEMP_DIR=%TEMP%\ggiholland_clean_build

echo 1. Oude tijdelijke map weggooien (echt alles wissen)...
if exist "%TEMP_DIR%" rmdir /S /Q "%TEMP_DIR%"
mkdir "%TEMP_DIR%"

echo 2. Kopiëren van project...
robocopy "%PROJECT_DIR:~0,-1%" "%TEMP_DIR%" /MIR /XD "build" ".dart_tool" ".git" /NFL /NDL /NJH /NJS /nc /ns /np

echo 3. Starten van flutter clean en APK Build...
cd /d "%TEMP_DIR%"
call flutter clean
call flutter build apk --release

if errorlevel 1 (
    echo =========================================
    echo FOUT: Het bouwen is mislukt!
    echo =========================================
    cd /d "%PROJECT_DIR%"
    exit /b %errorlevel%
)

echo 4. Kopiëren van voltooide APK...
cd /d "%PROJECT_DIR%"
copy /Y "%TEMP_DIR%\build\app\outputs\flutter-apk\app-release.apk" "%PROJECT_DIR%app-release.apk"

echo 5. Opruimen...
rmdir /S /Q "%TEMP_DIR%"
exit /b 0
