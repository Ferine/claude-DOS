@echo off 
cd .. 
cd .. 
cd .. 
IF NOT EXIST ".\games\!temp\" goto end 
".\dosbox\dosbox.exe" -conf ".\games\games\!temp\dosbox.conf" -noconsole -exit -fullscreen 
del stdout.txt 
del stderr.txt 
:end 
