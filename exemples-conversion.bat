@echo off

rem ouvrir setenv.bat pour configurer le chemin vers R
call setenv.bat

echo 5/7 - CSV vers HTML
%R_BIN%\Rscript.exe groum.R --input="data/arrete-cassis.csv" --output="outputs/arrete-cassis.html"
echo.

echo --------------------------------------------------------------------------------------------------------------------------------------

echo 6/7 - CSV vers GPKG
%R_BIN%\Rscript.exe groum.R --input="outputs/arrete-cassis-geo.csv" --output="outputs/arrete-cassis.gpkg" --geom=X_GEOM_WKT
echo.

echo --------------------------------------------------------------------------------------------------------------------------------------

echo 7/7 - CSV vers MD
%R_BIN%\Rscript.exe groum.R --input="data/arrete-cassis.csv" --output="outputs/arrete-cassis.md"

pause