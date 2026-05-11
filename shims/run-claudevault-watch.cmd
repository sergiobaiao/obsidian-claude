@echo off
set PYTHONUTF8=1
set PYTHONIOENCODING=utf-8
"%USERPROFILE%\claude-vault\venv\Scripts\claude-vault.exe" watch --vault-path "%USERPROFILE%\Nextcloud\Obsidian"
