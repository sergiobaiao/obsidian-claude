@echo off
cd /d "%USERPROFILE%\claude-vault"
set PYTHONUTF8=1
set PYTHONIOENCODING=utf-8
call "%USERPROFILE%\claude-vault\venv\Scripts\activate.bat"
claude-vault watch "%USERPROFILE%\Nextcloud\Obsidian\Conversations"
