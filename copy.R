arretePath <- "../../schema-arrete-circulation-marchandises-private/Cassis/arrete-cassis.csv"
schemaPath <- "../../schema-arrete-circulation-marchandises/schema.json"
streetsPath <- "../data/13022-Cassis.geojson"

# groomy
importsDir <- file.path("../../groumy/shinyapp", "helpers", "imports")
schemaDir  <- file.path("../../groumy/shinyapp", "www")
dataDir    <- file.path("../../groumy/shinyapp", "www")

# groum
importsDir <- file.path("../../groum/", "helpers", "imports")
schemaDir  <- file.path("../../groum/", "data")
dataDir    <- file.path("../../groum/", "data")

# Copie des fonctions
dir.create(importsDir)
file.copy("shinyapp/helpers/main.R", 
          file.path(importsDir, "main.R"),
          overwrite = T)

file.copy("shinyapp/helpers/markdown.R",
          file.path(importsDir, "markdown.R"),
          overwrite = T)

file.copy("shinyapp/helpers/opening-hours.R",
          file.path(importsDir, "opening-hours.R"),
          overwrite = T)

file.copy("shinyapp/helpers/geocode.R",
          file.path(importsDir, "geocode.R"),
          overwrite = T)

# Copie du schéma
file.copy(schemaPath,
          file.path(schemaDir, "schema.json"),
          overwrite = T)

# Copie des données
file.copy(arretePath,
          file.path(dataDir, "arrete-cassis.csv"),
          overwrite = T)

# Copie du JSON de rues
file.copy(streetsPath,
          file.path(dataDir, "13022-Cassis.geojson"),
          overwrite = T)