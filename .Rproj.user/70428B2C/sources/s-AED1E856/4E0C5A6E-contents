geocodeStreet <- function(street, streetsFile) {
  
  if(!file.exists(streetsFile)) {
    stop("Fichier de rues ,", streetsFile, " inexistant")
  }
  
  SearchAndRender <- function(street, sf_rues) {
    message("Nous recherchons la géométrie de la rue dénommée '", street, "'...")
    res <- get_rues(sf_rues, street)
    message("")
    message("La rue dont le nom est le plus proche est '", res$name, "'")
    message("Vous pouvez copier '", res$name,"' dans la colonne EMPRISE_DESIGNATION.")
    wkt <- res$wkt
    distance <- res$distance
    message("")
    message("Voici la géométrie de la rue '", res$name,"' :")
    message("---")
    message(wkt)
    message("---")
    message("Vous pouvez copier cette valeur dans la colonne GEOM_WKT de votre fichier")
  }
  
  sf_rues <- read_streets(streetsFile)
  if(grepl(",", street)) {
    streets <- strsplit(street, ",")[[1]] %>% trimws(which="both")
    for(i in 1:length(streets)) {
      street <- streets[i]
      SearchAndRender(street, sf_rues)
      if(i != length(streets)) message("\n===")
    }
  } else {
    SearchAndRender(street, sf_rues)
  }
}