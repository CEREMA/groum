@echo off

call setenv.bat
rem ouvrir setenv.bat pour configurer le chemin vers R

echo CSV vers GeoJSON
%R_BIN%\Rscript.exe groum.R --input="data/arrete-cassis-geo4.csv" --output="outputs/arrete-cassis.geojson" --geom=GEOM_WKT
echo.

echo ----

echo CSV vers GeoJSON (separation par types geometriques)
%R_BIN%\Rscript.exe groum.R --input="data/arrete-cassis-geo4.csv" --output="outputs/arrete-cassis.geojson" --geom=GEOM_WKT --separated

pause