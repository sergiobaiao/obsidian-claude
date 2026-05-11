@echo off
cd /d "%USERPROFILE%\claude-vault"
set PYTHONUTF8=1
set PYTHONIOENCODING=utf-8
call "%USERPROFILE%\claude-vault\venv\Scripts\activate.bat"
claude-vault sync "%APPDATA%\Claude\local-agent-mode-sessions" --vault-path "%USERPROFILE%\Nextcloud\Obsidian" --source code >> "%USERPROFILE%\claude-vault\cowork-periodic.log" 2>&1
