@echo off

call setenv.bat
rem ouvrir setenv.bat pour configurer le chemin vers R

echo CSV vers MD
%R_BIN%\Rscript.exe groum.R --input="data/arrete-cassis.csv" --output="outputs/arrete-cassis.md"

pause