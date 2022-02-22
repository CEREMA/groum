geocodeStreet <- function(street, streetsFile) {
  
  if(!file.exists(streetsFile)) {
    stop("Fichier de rues ,", streetsFile, " inexistant")
  }
  
  SearchAndRender <- function(street, sf_rues) {
    message(">> Géométrie de la rue ", street, " :")
    res <- get_rues(sf_rues, street)
    message(">> La rue dont le nom est le plus proche est ", res$name)
    wkt <- res$wkt
    distance <- res$distance
    message(wkt)
  }
  
  sf_rues <- read_streets(streetsFile)
  if(grepl(",", street)) {
    streets <- strsplit(street, ",")[[1]] %>% trimws(which="both")
    for(street in streets) {
      SearchAndRender(street, sf_rues)
    }
  } else {
    SearchAndRender(street, sf_rues)
  }
}