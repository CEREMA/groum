@echo off

set R_SCRIPT=C:\R\R-4.0.4\bin\Rscript.exe groum.R

echo GEOCODAGE
echo %R_SCRIPT%
echo %1
echo %2
echo %3
echo %4
%R_SCRIPT% %1

pause