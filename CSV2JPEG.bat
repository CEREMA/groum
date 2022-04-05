@echo off

call setenv.bat
rem ouvrir setenv.bat pour configurer le chemin vers R

echo CSV vers JPEG
%R_BIN%\Rscript.exe groum.R --input="data/arrete-cassis-geo4.csv" --output="outputs/arrete-cassis.jpeg" --geom=GEOM_WKT

pause