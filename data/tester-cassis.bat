@echo off

call setenv.bat

:: exemple générique
%frictionless%  validate --schema schema.json arrete-cassis-geo4.csv

pause