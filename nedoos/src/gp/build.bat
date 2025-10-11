if "%settedpath%"=="" call ../_sdk/setpath.bat
if not exist gp mkdir gp
sjasmplus --nologo --msg=war mwm.asm
sjasmplus --nologo --msg=war pt3.asm
sjasmplus --nologo --msg=war ngsdec/gscode.asm
sjasmplus --nologo --msg=war mp3.asm
sjasmplus --nologo --msg=war vgm.asm
sjasmplus --nologo --msg=war moonmod.asm
sjasmplus --nologo --msg=war main.asm
copy /b gp1.plr + gp2.plr gp.plr
rem sjasmplus --nologo --msg=war moonmod/generateperiodlookup.asm


SET releasedir2=../../release/
if "%currentdir%"=="" (
  FOR %%j IN (*.com) DO (
  "../../tools/dmimg.exe" ../../us/sd_nedo.vhd put %%j /bin/%%j
  move "*.com" "%releasedir2%bin" > nul
  IF EXIST %%~nj xcopy /Y /E "%%~nj" "%releasedir2%bin\%%~nj\" > nul
  )

  cd ../../src/

  call ..\tools\chkimg.bat sd
  rem call ..\tools\chkimg.bat hdd

  rem pause

 if "%makeall%"=="" ..\us\emul.exe
)