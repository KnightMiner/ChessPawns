@echo off

IF EXIST build RMDIR /q /s build
IF EXIST "Chess-Pawns-#.#.#.zip" DEL "Chess-Pawns-#.#.#.zip"
MKDIR build
MKDIR build\ChessPawns

REM Copy required files into build directory
XCOPY img build\ChessPawns\img /s /e /i
XCOPY scripts build\ChessPawns\scripts /s /e /i

REM Zipping contents
powershell.exe -nologo -noprofile -command "& { Add-Type -A 'System.IO.Compression.FileSystem'; [IO.Compression.ZipFile]::CreateFromDirectory('build', 'Chess-Pawns-#.#.#.zip'); }"

REM Removing build directory
