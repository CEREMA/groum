@echo off

call setenv.bat

:: exemple g�n�rique
%frictionless%  validate --schema schema.json arrete-cassis-geo4.csv

pause