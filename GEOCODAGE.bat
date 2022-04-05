@echo off

rem ouvrir setenv.bat pour configurer le chemin vers R
call setenv.bat

echo GEOCODAGE D UNE RUE
%R_BIN%\Rscript.exe groum.R --input="Chemain du Plan d'Ollive" --streets="data/13022-Cassis.geojson"
echo.

echo ----

echo GEOCODAGE DE DEUX RUES
%R_BIN%\Rscript.exe groum.R --input="Chemain du Plan d'Ollive,esplanade Charle de Gaule" --streets="data/13022-Cassis.geojson"
echo.

echo ----

echo GEOCODAGE D UNE COMMUNE
%R_BIN%\Rscript.exe groum.R --input="Commune de Cassis"
echo.

echo ----

echo GEOCODAGE CSV
%R_BIN%\Rscript.exe groum.R --input="data/arrete-cassis.csv" --output="outputs/arrete-cassis-geo.csv" --streets="data/13022-Cassis.geojson"
echo.

pause