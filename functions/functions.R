CSV2JPEG <- function(inputCSV, geomCol = "GEOM_WKT", outputJPEG, width = 800) {
  
  # export_snapshot(
  # inputCSV = "../data/arrete-cassis-geo2.csv",
  # geomCol = "X_GEOM_WKT",
  # outputJPEG = "../outputs/cassis.jpeg",
  # width = 1200)
  
  message("Lecture de ", inputCSV)
  f <- read_arrete(inputCSV) %>% as_spatial(geom_col = geomCol)
  
  # Points, lignes et polygones
  f_points   <- f[grep("point", tolower(st_geometry_type(f))), ] %>% st_geometry
  n_empty <- which(st_is_empty(f_points)) %>% length
  f_lines    <- f[grep("line", tolower(st_geometry_type(f))), ] %>% st_geometry
  f_polygons <- f[grep("polygon", tolower(st_geometry_type(f))), ] %>% st_geometry
  
  # Largeur et hauteur
  bb <- st_bbox(f)
  ratio <- abs(bb$ymin - bb$ymax) / abs(bb$xmin - bb$xmax)
  
  # Export
  message("Export vers ", outputJPEG)
  jpeg(filename = outputJPEG, width=width, height = width*ratio)
  
  # Eléments cartos
  plot(f_polygons, lwd = 1, col="#e3e2de", border = NA, xlim=c(bb$xmin, bb$xmax), ylim=c(bb$ymin, bb$ymax))
  plot(f_lines, add = T, col="black", lwd = 1)
  plot(f_points, add = T, col="white", bg="red", pch=21)
  
  # Titre et sous-titre
  COLL_NOM <- head(f$COLL_NOM, 1)
  COLL_INSEE <- head(f$COLL_INSEE, 1)
  titre <- glue("{COLL_NOM}({COLL_INSEE})")
  sousTitre <- glue("{n_empty} éléments sans référence géométrique")
  title(main = titre, sub = sousTitre)
  
  dev.off()
}

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