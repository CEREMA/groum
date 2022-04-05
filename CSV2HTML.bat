@echo off

call setenv.bat
rem ouvrir setenv.bat pour configurer le chemin vers R

echo CSV vers HTML
%R_BIN%\Rscript.exe groum.R --input="data/arrete-cassis.csv" --output="outputs/arrete-cassis.html"

pause