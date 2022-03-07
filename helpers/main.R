geocode_street <- function(street, streetsFile = NA) {
  
  SearchAndRender <- function(street, sf_rues) {
    message("Nous recherchons la géométrie de la rue dénommée '", street, "'...")
    res <- geocode_elements(street, sf_rues)
    message("")
    message("La rue dont le nom est le plus proche est '", res$name, "'")
    message("Vous pouvez copier '", res$name,"' dans la colonne EMPRISE_DESIGNATION.")
    wkt <- res$wkt
    distance <- res$distance
    message("")
    message("Voici la géométrie de '", res$name,"' :")
    message("---")
    message(wkt)
    message("---")
    message("Vous pouvez copier cette valeur dans la colonne GEOM_WKT de votre fichier")
  }
  
  if(length(streetsFile) == 0) {
    sf_rues <- NA    
  } else if(is.na(streetsFile)) {
    sf_rues <- NA    
  } else {
    if(!file.exists(streetsFile)) {
      stop("Fichier de rues ,", streetsFile, " inexistant")
    } else {
      sf_rues <- read_streets(streetsFile)
    }
  }
  
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