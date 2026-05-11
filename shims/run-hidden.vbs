' run-hidden.vbs — Launches a .cmd file completely silently (no window).
' Usage: wscript.exe run-hidden.vbs "C:\path\to\shim.cmd"
'
' The second argument to oShell.Run is the window style:
'   0 = SW_HIDE — guaranteed no console window, even when launched from Task Scheduler.
' The third argument (False) means wscript exits immediately; the cmd process
' runs independently in the background.
Dim oShell, cmd
Set oShell = CreateObject("WScript.Shell")
cmd = WScript.Arguments(0)
oShell.Run "cmd.exe /c """ & cmd & """", 0, False
