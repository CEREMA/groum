@echo off

rem set your R script folder here
rem see scripts\install-libraries.R to install the packages
set R_SCRIPT=C:\R\R-4.0.4\bin\Rscript.exe groum.R

echo GEOCODAGE UNE RUE
%R_SCRIPT% --input="Chemain du Plan d'Ollive" --streets="data/13022-Cassis.geojson"
echo.

echo GEOCODAGE DEUX RUES
%R_SCRIPT% --input="Chemain du Plan d'Ollive,esplanade Charle de Gaule" --streets="data/13022-Cassis.geojson"
echo.

echo GEOCODAGE FICHIER
%R_SCRIPT% --input="data/arrete-cassis.csv" --output="outputs/arrete-cassis2.csv" --streets="data/13022-Cassis.geojson"
echo.

echo HTML
%R_SCRIPT% --input="data/arrete-cassis.csv" --output="outputs/arrete-cassis.html"
echo.

echo GPKG
%R_SCRIPT% --input="outputs/arrete-cassis2.csv" --output="outputs/arrete-cassis.gpkg" --geom=X_GEOM_WKT
echo.

echo MD
%R_SCRIPT% --input="data/arrete-cassis.csv" --output="outputs/arrete-cassis.md"

pause