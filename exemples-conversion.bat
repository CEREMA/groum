@echo off

call setenv.bat
rem ouvrir setenv.bat pour configurer le chemin vers R

echo 5/8 - CSV vers HTML
%R_BIN%\Rscript.exe groum.R --input="data/arrete-cassis.csv" --output="outputs/arrete-cassis.html"
echo.

echo --------------------------------------------------------------------------------------------------------------------------------------

echo 6/8 - CSV vers GPKG
%R_BIN%\Rscript.exe groum.R --input="data/arrete-cassis-geo4.csv" --output="outputs/arrete-cassis.gpkg" --geom=GEOM_WKT
echo.

echo --------------------------------------------------------------------------------------------------------------------------------------

echo 7/8 - CSV vers JPEG
%R_BIN%\Rscript.exe groum.R --input="data/arrete-cassis-geo4.csv" --output="outputs/arrete-cassis.jpeg" --geom=GEOM_WKT

echo --------------------------------------------------------------------------------------------------------------------------------------

echo 8/8 - CSV vers MD
%R_BIN%\Rscript.exe groum.R --input="data/arrete-cassis.csv" --output="outputs/arrete-cassis.md"

pause