@echo off
setlocal
echo =========================================
echo Bouwen van GGIHolland APK (Google Drive Workaround)
echo =========================================

set PROJECT_DIR=%~dp0
set TEMP_DIR=%TEMP%\ggiholland_build

echo 1. Schoonmaken oude tijdelijke map...
if exist "%TEMP_DIR%" rmdir /S /Q "%TEMP_DIR%"
mkdir "%TEMP_DIR%"

echo 2. Kopiëren van project naar C: schijf (om Flutter fouten te voorkomen)...
robocopy "%PROJECT_DIR:~0,-1%" "%TEMP_DIR%" /MIR /XD "build" ".dart_tool" ".git" /NFL /NDL /NJH /NJS /nc /ns /np

echo 3. Starten van de APK Build (dit kan even duren)...
cd /d "%TEMP_DIR%"
call flutter build apk --release

if errorlevel 1 (
    echo =========================================
    echo FOUT: Het bouwen is mislukt!
    echo =========================================
    cd /d "%PROJECT_DIR%"
    pause
    exit /b %errorlevel%
)

echo 4. Kopiëren van de voltooide APK naar je Google Drive...
cd /d "%PROJECT_DIR%"
copy /Y "%TEMP_DIR%\build\app\outputs\flutter-apk\app-release.apk" "%PROJECT_DIR%app-release.apk"

echo 5. Opruimen tijdelijke bestanden...
rmdir /S /Q "%TEMP_DIR%"

echo =========================================
echo SUCCES! Je nieuwe APK is succesvol aangemaakt:
echo "%PROJECT_DIR%app-release.apk"
echo =========================================
pause
