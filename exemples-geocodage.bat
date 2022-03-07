@echo off

rem ouvrir setenv.bat pour configurer le chemin vers R
call setenv.bat

echo 1/7 - GEOCODAGE D UNE RUE
%R_BIN%\Rscript.exe groum.R --input="Chemain du Plan d'Ollive" --streets="data/13022-Cassis.geojson"
echo.

echo --------------------------------------------------------------------------------------------------------------------------------------

echo 2/7 - GEOCODAGE DEUX RUES
%R_BIN%\Rscript.exe groum.R --input="Chemain du Plan d'Ollive,esplanade Charle de Gaule" --streets="data/13022-Cassis.geojson"
echo.

echo --------------------------------------------------------------------------------------------------------------------------------------

echo 3/7 - GEOCODAGE D UNE COMMUNE
%R_BIN%\Rscript.exe groum.R --input="Commune de Cassis"
echo.

echo --------------------------------------------------------------------------------------------------------------------------------------

echo 4/7 - GEOCODAGE CSV
%R_BIN%\Rscript.exe groum.R --input="data/arrete-cassis.csv" --output="outputs/arrete-cassis-geo.csv" --streets="data/13022-Cassis.geojson"
echo.

pause