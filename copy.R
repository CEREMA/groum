setwd("C:/Users/mathieu.rajerison/Desktop/TAFF_MAISON/GIT/groum")

# Copie des fonctions
file.copy("../groum-groum/src/shinyapp/libraries.R", 
          file.path("functions/imports", "libraries.R"),
          overwrite = T)

file.copy("../groum-groum/src/shinyapp/helpers/main.R", 
          file.path("functions/imports", "main.R"),
          overwrite = T)

file.copy("../groum-groum/src/shinyapp/helpers/markdown.R",
          file.path("functions/imports", "markdown.R"),
          overwrite = T)

file.copy("../groum-groum/src/shinyapp/helpers/opening-hours.R",
          file.path("functions/imports", "opening-hours.R"),
          overwrite = T)

file.copy("../groum-groum/src/shinyapp/helpers/geocode.R",
          file.path("functions/imports", "geocode.R"),
          overwrite = T)

# Copie du schéma
file.copy("../schema-arrete-circulation-marchandises/schema.json",
          file.path("data", "schema.json"),
          overwrite = T)

# Copie des données
file.copy("../schema-arrete-circulation-marchandises-private/Collectivités/Cassis/3-arrete/arrete-cassis.csv",
          file.path("data", "arrete-cassis.csv"),
          overwrite = T)

# Copie du JSON de rues
file.copy("../schema-arrete-circulation-marchandises-private/Collectivités/Cassis/13022-Cassis.geojson",
          file.path("data", "13022-Cassis.geojson"),
          overwrite = T)