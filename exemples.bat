@echo off

rem set your R script folder here
rem see scripts\install-libraries.R to install the packages
set R_BIN=C:\R\R-4.0.4\bin\

echo GEOCODAGE UNE RUE
%R_BIN%\Rscript.exe groum.R --input="Chemain du Plan d'Ollive" --streets="data/13022-Cassis.geojson"
echo.

echo GEOCODAGE DEUX RUES
%R_BIN%\Rscript.exe groum.R --input="Chemain du Plan d'Ollive,esplanade Charle de Gaule" --streets="data/13022-Cassis.geojson"
echo.

echo GEOCODAGE FICHIER
%R_BIN%\Rscript.exe groum.R --input="data/arrete-cassis.csv" --output="outputs/arrete-cassis2.csv" --streets="data/13022-Cassis.geojson"
echo.

echo HTML
%R_BIN%\Rscript.exe groum.R --input="data/arrete-cassis.csv" --output="outputs/arrete-cassis.html"
echo.

echo GPKG
%R_BIN%\Rscript.exe groum.R --input="outputs/arrete-cassis-geo.csv" --output="outputs/arrete-cassis.gpkg" --geom=X_GEOM_WKT
echo.

echo MD
%R_BIN%\Rscript.exe groum.R --input="data/arrete-cassis.csv" --output="outputs/arrete-cassis.md"

pause