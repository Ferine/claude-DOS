@ECHO OFF
REM Test batch file for ClaudeDOS
ECHO === Batch File Test ===
ECHO.
ECHO Testing parameters: %0 %1 %2
ECHO.
ECHO Testing FOR loop:
FOR %%F IN (HELLO MEM DIR) DO ECHO - %%F
ECHO.
ECHO Testing IF EXIST:
IF EXIST HELLO.COM ECHO HELLO.COM exists
IF NOT EXIST NOFILE.XXX ECHO NOFILE.XXX does not exist
ECHO.
ECHO === Test Complete ===
