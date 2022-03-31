as_spatial <- function(df, geom_col = "GEOM_WKT") {
  
  if(!(geom_col %in% names(df))) {
    # Si la colonne géométrique n'existe pas
    the_col <- grep("GEOM_WKT", names(df))
    if(length(the_col) == 0) {
      stop("La colonne ", geom_col, " n'existe pas. Avez-vous voulu dire ", the_col, " ?")
    } else {
      stop("La colonne ", geom_col, " n'existe pas")
    }
  } else {
    
    # Si la colonne géométrique ne comprend pas de valeurs
    if(all(is.na(df[[geom_col]])) | all(df[[geom_col]] == "")) {
      stop("La colonne ", geom_col, " est vide")
    } else {
      
      # w <- which(df[[geom_col]] != "" | df[[geom_col]] == "N/C" | df[[geom_col]] == "NA" | is.na(df[[geom_col]]))
      w <- grep("^(point|multipoint|line|multiline|polygon|multipolygon|geometry)", tolower(df[[geom_col]]))

      if(length(w) == 0) stop("La colonne ", geom_col, " est vide")
      
      # On met une géométrie vide si pas de géométrie pour la ligne
      df[[geom_col]][-w] <- "POINT EMPTY"
      st_geometry(df) <- st_as_sfc(df[[geom_col]])
      
      return(df)
    }
  }
}

CSV2GPKG <- function(inputCSV, outputSpatial, geomCol = "GEOM_WKT") {
  
  # Lecture du fichier
  message("Lecture de ", inputCSV)
  df <- read_arrete(inputCSV)
  
  # Conversion en spatial
  f <- as_spatial(df, geom = geomCol)
      
  # Export
  message("Export vers ", outputSpatial)
  export_spatial(f, outputSpatial)
}

export_spatial <- function(f, 
                        outputSpatial, 
                        split_by_geomtype = FALSE) {
  
  st_write(f %>% st_set_crs(4326), 
           outputSpatial, 
           delete_dsn = TRUE)
  
  # if(length(grep("POLYGON", st_geometry_type(f))) == 0) {
  #   # Si on n'a pas de surfaces, alors on exporte directement les lignes en un seul fichier
  #   message("Export de ", outputFile)
  #   st_write(f, outputFile, delete_dsn = TRUE)
  # } else if(!split_by_geomtype) {
  #   message("Export de ", outputFile)
  #   st_write(f, outputFile, delete_dsn = TRUE)
  # } else {
  #   # Export des lignes
  #   outputLinePath <- gsub(".gpkg$", "-lines.gpkg", outputFile)
  #   message("Export de ", outputLinePath)
  #   f.lines <- f[grep("LINESTRING", st_geometry_type(f)), ]
  #   st_write(f.lines, outputLinePath, delete_dsn = TRUE)
  #   
  #   # Export des polygones
  #   outputPolygonPath <- gsub(".gpkg$", "-polygons.gpkg", outputFile)
  #   message("Export de ", outputPolygonPath)
  #   f.polygons <- f[grep("POLYGON", st_geometry_type(f)), ]
  #   st_write(f.polygons, outputPolygonPath, delete_dsn = TRUE)
  # }
}

export_gpkg_by_vehicles <- function(f, outputDir) {
  
  f$file_name <- f %>% format_vehicule %>% pull(VEHICULE) %>% {gsub(" ", "-", .)} %>% {glue("{.}.gpkg")}
  file_names <- unique(f$file_name)
  
  for(elt in file_names) {
    f.sel <- f %>% filter(file_name == elt)
    export_gpkg(f.sel, file.path(outputDir, elt))
  }
}

contains_insee <- function(label) {
  grepl("^.*([013-9]\\d|2[AB1-9])\\d{3}.*$", label)
}

geocode_commune <- function(label) {
  if(contains_insee(label)) {
    code_insee <- gsub("^.*((?:[013-9]\\d|2[AB1-9])\\d{3}).*$", "\\1", label)
  } else if(grepl("^Commune.*|^commune.*", label)) {
    # Commune de ...
    label <- gsub("(?:C|c)ommune\\s(?:d'|d’|de\\s)?(.*)", "\\1", label)
    code_insee <- get_code_insee_from_nom(label)
    # code_insee <- get_code_insee_from_nom(nom_comm, f_ref)
  } else if(grepl("^Ville.*|^ville.*", label)) {
    # Ville de ...
    label <- gsub("^(?:V|v)ille\\s?(?:d'|d’|de)?(.*)$", "\\1", label)
    code_insee <- get_code_insee_from_nom(label)
    # code_insee <- get_code_insee_from_nom(nom_comm, f_ref)
  } else {
    code_insee <- get_code_insee_from_nom(label)
  }
  
  if(is.null(code_insee)) {
    return()
  } else {
    res <- get_df_commune(code_insee) %>% transform_df
    return(res)
  }
}

geocode_element <- function(label, 
                            f_ref       = NA, 
                            nameCol     = "name", 
                            processMode = "auto",  # auto # manual
                            findMode    = "distance",
                            cleanMode   = NA) {
  # !! empty_sf ptet à réactiver
  
  # Choix de la fonction en fonction du mode
  if(findMode == "distance") {
    find_function <- find_similar
  } else {
    find_function <- find_containing
  }
  
  # AUTO mode
  if(processMode == "auto") {
    # Si le mode est auto, on essaie de savoir si on a affaire à une commune ou pas.
    if(is_commune(label)) {
        # géocodage de commune (fait appel à API)
        res <- geocode_commune(label)
      } else {
        # on va utiliser nameCol cette fois-ci et on va utiliser f_ref
        # nameCol doit exister dans f_ref
        # Si la colonne nameCol n'existe pas, on provoque une erreur
        if(!(nameCol %in% names(f_ref))) stop("Colonne ", nameCol, " absente.")
        
        res <- label %>% 
          find_function(f_ref      = f_ref,
                        cleanMode  = cleanMode) %>% 
          mutate(`type` = "Street") %>% 
          transform_df
      }
  }
  
  # MANUAL mode
  if(processMode == "manual") {
    res <- label %>% 
      find_function(f_ref      = f_ref,
                    cleanMode  = cleanMode) %>% 
      mutate(`type` = NA) %>% 
      transform_df
  }
    
  # On cherche la rue dont le nom le plus ressemblant
  # et on constitue le data frame final
    
  
  return(res)
}

geocode_CSV <- function(streets, inputCSV, outputCSV, communes = NA) {
  if(!file.exists(inputCSV)) {
    stop(inputCSV, " n'existe pas")
  }
  
  if(!dir.exists(dirname(outputCSV))) {
    stop("Dossier ", dirname(outputCSV), " inexistant")
  }
  
  # On lit le fichier d'entrée
  message("Lecture de ", inputCSV)
  df <- read.csv(inputCSV, header = TRUE, sep = ",", encoding = "UTF-8")
  
  # On récupère le fichier de rues
  if(!file.exists(inputCSV)) {
    stop("Le fichier de rues ", streets, " n'existe pas")
  }
  
  f_ref <- read_streets(streets)
  
  # On apparie
  res <- geocode_elements(labels      = df$EMPRISE_DESIGNATION,
                          f_ref       = f_ref,
                          processMode = "auto",
                          findMode    = "distance")
  
  # On met à jour le fichier initial
  df2 <- df %>% update_file(res = res)
  
  # On l'exporte
  message("Export de ", outputCSV)
  write.csv(df2, outputCSV, fileEncoding = "UTF-8", row.names = FALSE)
}

geocode_elements <- function(labels, 
                             f_ref,               # Fichier de référence depuis lequel contrôler les données
                             nameCol     = "name",    # Colonne du fichier de référence contenant les noms
                             processMode = "auto",     # street, commune : réfléchir aussi aux POI
                             findMode    = "distance") { # 'distance' ou 'containing'
  
  # message("Recherche des rues dont les noms sont les plus proches...")
  
  out <- vector(mode="list")
  for(i in 1:length(labels)) {
    label <- labels[i]
    res <- geocode_element(label = label, 
                          f_ref,
                          processMode = processMode,
                          findMode = findMode)
    out[[i]] <- res
  }
  
  data <- do.call(rbind, out)
  
  return(data)
}

empty_sf <- function(rue) {
  data.frame(name = rue, 
             type = "City",
             union = NA, 
             n = NA, 
             distance = NA,
             geometry = "LINESTRING(EMPTY)"
  ) %>%
    st_as_sf(wkt = "geometry") %>% 
    mutate(wkt = "LINESTRING(EMPTY)") %>% 
    st_set_crs(4326)
}

get_code_insee_from_nom <- function(label) {
  url <- glue("https://geo.api.gouv.fr/communes?nom={label}&fields=departement&boost=population&limit=5")
  code_insee   <- try(jsonlite::fromJSON(url)$code[1], silent = TRUE)
  if(!inherits(code_insee, "try-error")) {
    code_insee
  } else {
    return()
  }
}

get_wkt_from_insee <- function(code_insee) {
  
  url <- glue("https://geo.api.gouv.fr/communes/{code_insee}?format=geojson&geometry=contour&fields=geometry")
  
  j <- jsonlite::fromJSON(url)
  
  coords   <- j$geometry$coordinates[1,,]
  geometry <- st_polygon(list(coords)) %>% st_sfc %>% st_set_crs(4326)
  nom      <- j$properties$nom
  wkt      <- geometry %>% st_as_text()
  
  list(code_insee = code_insee,
       nom        = nom,
       wkt        = wkt, 
       geometry   = geometry)
}

get_df_commune <- function(code_insee) {
  
  # Si le code INSEE est nul, alors on renvoie un sf data frame vide
  if(is.null(code_insee)) {
    res <- empty_sf(libelle)
    return(res)
  }
  
  # On récupère la chaîne WKT correspondant au code commune
  # Utilise geo.api.gouv.fr
  res <- get_wkt_from_insee(code_insee)
  
  # Si le code INSEE n'est pas dans le libellé de rue, alors on reformate l'entrée
  libelle <- glue("{res$nom} ({res$code_insee})")
  
  # On crée l'objet résultat
  res <- data.frame(name     = libelle, 
                    type     = "City",
                    union    = NA, 
                    n        = NA,
                    wkt      = res$wkt,
                    distance = NA
                    ) %>% 
    st_as_sf(wkt = "wkt") %>% 
    rename(geometry = wkt) %>% 
    mutate(wkt = res$wkt) %>% 
    st_set_crs(4326) %>% 
    dplyr::select(name, type, union, n, wkt, geometry)
  
  # Ajout de la colonne géométrie
  # res$geometry <- st_geometry(res)
  
  return(res)
  # return(list(df_data = as.data.frame(res) %>% drop_geometry_column, 
  #             sf_data = res))
}

transform_df <- function(df) {
  df %>% dplyr::select(name, type, union, n, wkt, geometry)
}

OLD_geocode_element <- function(label,
                            f_ref,
                            nameCol = "name",
                            mode = "distance",
                            type = "Street") {
  
  if(!(nameCol %in% names(f_ref))) stop("Colonne ", nameCol, " absente.")
  
  # Récupération de la commune
  # Choix de la fonction
  if(mode == "distance") {
    my_find_function <- find_similar
  } else {
    my_find_function <- find_containing
  }
  
  # On cherche la rue la plus ressemblante
  res <- label %>% 
    my_find_function(f_ref = f_ref,
                type  = type) %>% 
    mutate(`type` = type) %>% 
    transform_df
  
  # On en récupère la chaîne WKT
  # res2 <- get_wkt(label = as.character(res$name),
  #                 f_ref = f_ref) %>% 
  #   mutate(distance = res$distance)
  # 
  # res$type <- type
  # 
  # res <- res 
  
  return(res)
  # return(list(df_data = as.data.frame(data) %>% drop_geometry_column, 
  #             sf_data = data))
}

# Méthode permettant de trouver les rues qui contiennent 
# un des éléments compris dans une chaîne de caractères
# Par exemple, "Philippe Solari" va être trouvé dans "Avenue Philippe Solari" 
# avec un score de 2 puisque Philippe et Solari sont tous deux trouvés
# (Avenue est supprimé de la recherche)
# "Rue Philippe Rollin" aura un score de 1
# Ainsi, si n_result est égal à 1, le score le plus haut sera retourné
# et "Avenue Philippe Solari" constituera la réponse
find_containing <- function(rue, f_ref, n, nameCol = "name", area = "commune") {
  message("Mode : find streets containing")
  f_ref_names <- unique(f_ref[[nameCol]])
  clean1 <- clean_street_names(rue)
  clean2 <- clean_street_names(f_ref_names)
  split1 <- strsplit(clean1, " ")[[1]]
  split2 <- strsplit(clean2, " ")
  
  out <- vector(mode = "list")
  i <- 1
  j <- 1
  for(elt1 in split1) {
    message(">", elt1)
    for(j in 1:length(split2)) {
      
      elt2 <- split2[[j]]
      
      elt2 <- setdiff(elt2, c("de", "du", "des", "d'"))
      elt2 <- setdiff(elt2, c("la", "le", "les"))
      elt2 <- setdiff(elt2, c("et", "en"))
      
      for(elt3 in elt2) {
        if(elt1 == elt3) {
          destination <- paste(elt2, collapse = " ")
          out[[i]] <- data.frame(element = elt1, index = j)
          i <- i + 1
        }
      }
    }
  }
  
  if(length(out) == 0) return()
  
  res <- do.call(rbind, out) %>% 
    group_by(index) %>% 
    summarize(note = n(), elements = paste(element, collapse=", ")) %>% 
    data.frame %>% 
    ungroup %>% 
    arrange(desc(note)) %>% 
    head(n) %>% 
    mutate(source = rue) %>% 
    mutate(name = f_ref_names[.$index])
  
  return(res)
}

clean_commune_names <- function(label) {
  label <- gsub("Ville de ", "", label)
  label <- gsub("ville de ", "", label)
  label <- gsub("Commune de ", "", label)
  label <- gsub("commune de ", "", label)
  label <- gsub("*([013-9]\\d|2[AB1-9])\\d{3}", "", label)
  label <- gsub("\\)", "", label)
  label <- gsub("\\(", "", label)
  label <- trimws(label, which = "both")
  label
}

find_similar <- function(label,
                         f_ref, 
                         nameCol   = "name",
                         cleanMode = NA) {
  
  # message("Find similar Streets")
  
  # Choix de la fonction de nettoyage
  if(is.na(cleanMode)) {
    sourceLabels <- label
    targetLabels <- f_ref[[nameCol]]
  } else if(cleanMode == "Street") {
    sourceLabels <- clean_street_names(label)
    targetLabels <- clean_street_names(f_ref[[nameCol]])
  } else if (cleanMode == "city") {
    sourceLabels <- clean_commune_names(label)
    targetLabels <- clean_commune_names(f_ref[[nameCol]])
  }
  
  # Distance de levenshtein entre les rues
  d <- stringdist(sourceLabels, 
                  targetLabels,
                  method = "dl")
  
  # Récupération de la meilleure note pour la rue
  df <- data.frame(name     = f_ref[[nameCol]], 
                   distance = d,
                   # id       = f_ref[[idCol]]) %>% 
                   id       = 1:nrow(f_ref)) %>% 
    group_by_at(nameCol) %>% 
    summarize(ids       = paste(id, collapse=","), 
              distance  = mean(distance), 
              n         = n()) %>% 
    data.frame %>% 
    # On trie selon la note
    arrange(distance) %>% 
    # On prend les n résultats
    head(1)
  
  # Ajout de la composante géométrique
  w <- which(f_ref[[nameCol]] == df$name)
  f_sel <- f_ref %>% slice(w)
  n_geoms <- f_sel %>% nrow
  if(n_geoms == 1) {
    geom <- f_sel %>% st_geometry
    df$wkt   <- geom %>%  st_as_text()
    df$union <- FALSE
    st_geometry(df)  <- geom
  } else {
    geom <- st_union(f_sel)
    df$wkt   <- geom %>% st_as_text()
    df$union <- TRUE
    st_geometry(df)  <- geom
  }
  
  # WKT
  # res2 <- get_wkt(label = as.character(res$name),
  #                 f_ref = f_ref) %>% 
  #   mutate(distance = res$distance)
  
  return(df)
}

read_json <- function(url) {
  # url <- "https://raw.githubusercontent.com/glynnbird/usstatesgeojson/master/california.geojson"
  sf <- geojson_sf(url) %>% st_zm(drop = T) 
  
  # Filter
  sf <- sf %>% filter(name != "" & !is.na(name))
  
  # Suppression de la dimension Z
  sf <- sf %>% st_zm(drop = TRUE)
  
  sf
}

read_streets <- function(inputFile) {
  # message("read_streets (lecture des rues) ", inputFile)
  extension <- gsub(".*\\.(.*)", "\\1", inputFile)
  
  if(extension %in% c("json", "geojson")) {
    sf <- read_json(inputFile)
    sf$name <- stri_encode(sf$name, "UTF-8", "UTF-8")
    sf
  } else if (extension %in% c("shp", "gpkg")) {
    sf <- st_read(inputFile)
    sf$name <- stri_encode(sf$name, "UTF-8", "UTF-8")
    sf
  } else {
    stop("Format .", extension, " non pris en charge")
  }
}

# rename_colonnes <- function(sf, producteur) {
#   
#   print(names(sf))
#   
#   # Renommage
#   if(producteur == "IGN") {
#     sf2 <- sf %>% rename(name = nom_1_gauche, index = cleabs)
#   } else if(producteur == "OSM") {
#     sf2 <- sf %>% rename(name = name, index = osm_id)
#   }
#   
#   sf2
# }

clean_street_names <- function(street_names) {
  
  street_names <- tolower(street_names)
  
  # on supprime ce qui est entre parenthèsés
  # par exemple, Chemin de la Clue (dans sa partie circulable coté EST de la route de Cagnes)
  street_names <- gsub("\\s?\\(.*\\)\\s?", "", street_names) 
  
  street_names <- gsub("rue|Rue", "", street_names)
  street_names <- gsub("cours|Cours", "", street_names)
  street_names <- gsub("avenue|Avenue", "", street_names)
  street_names <- gsub("route|Route", "", street_names)
  street_names <- gsub("chemin|Chemin", "", street_names)
  street_names <- gsub("rond-point|Rond-Point", "", street_names)
  street_names <- gsub("allée|Allée", "", street_names)
  street_names <- gsub("boulevard|Boulevard", "", street_names)
  street_names <- gsub("impasse|Impasse", "", street_names)
  
  street_names <- gsub("rte de", "", street_names)
  street_names <- gsub("rte de la", "", street_names)
  street_names <- gsub("rte des", "", street_names)
  
  street_names <- gsub("che du", "", street_names)
  street_names <- gsub("che de la", "", street_names)
  street_names <- gsub("che des", "", street_names)
  
  street_names <- gsub("pl de la", "", street_names)
  street_names <- gsub("pl du", "", street_names)
  street_names <- gsub("pl des", "", street_names)
  
  street_names <- gsub("r de la", "", street_names)
  street_names <- gsub("r du", "", street_names)
  street_names <- gsub("r des", "", street_names)
  
  street_names <- gsub("^\\s?d'|^\\s?de\\s|^\\s?des\\s|^\\s?du\\s|^\\s?de la\\s", "", street_names)
  street_names <- gsub("^\\s", "", street_names)
  
  return(street_names)
}

is_commune <- function(libelle) {
  grepl("^Commune.*|^commune.*|^Ville.*|^ville.*$|^.*([013-9]\\d|2[AB1-9])\\d{3}.*$", libelle)
}

OLD_get_wkt <- function(label = NA, 
                    f_ref, 
                    # the_index = NA,
                    nameCol = "name") {
  
  # On se base sur l'OSM ID si pas de nom de rue
  # Pas de fusion des géométries
  # if(is.na(label)) {
  #   n <- 1
  #   f.sel <- f_ref %>% filter(index == the_index)
  #   geom <- f.sel  %>% st_geometry
  #   wkt <- geom %>% st_as_text()
  #   nom_rue <- f.sel$name
  #   union <- FALSE
  # }
  
  # On se base sur name
  # Fusion des géométries
  # if(is.na(the_index)) {
    w <- which(f_ref[[nameCol]] == label)
    f.sel <- f_ref %>% slice(w)
    n <- f.sel %>% nrow
    if(n == 1) {
      geom <- f.sel %>% st_geometry
      wkt <- geom %>%  st_as_text()
      union <- FALSE
    } else {
      geom <- st_union(f.sel)
      wkt <- geom %>% st_as_text()
      union <- TRUE
    }
  # }
  
  res <- data.frame(name  = label,
                    type  = "Street", # !! changer cela
                    union = union, 
                    n     = n,
                    wkt   = wkt)
  st_geometry(res) <- geom
  
  return(res)
}

drop_geometry_column <- function(df) {
  df %>% dplyr::select(-geometry)
}

update_file <- function(df, res, producteur = "OSM") {
  # On n'a pas intégré les colonnes n et union
  data <- df %>% mutate(
                        `_EMPRISE_DESIGNATION` = res$name,
                        `_GEOM_WKT`               = res$wkt,
                        `_GEOM_SOURCE`            = producteur,
                        `_TYPE`                = res$type,
                        `_DISTANCE`            = res$distance
                        )
  
  data
}

OLD_update_file_df <- function(df, df_data, producteur = NA) {
  m <- match(df$EMPRISE_DESIGNATION, df_data$name)
  df_data <- df_data[m, ]
  df_data <- df %>% mutate(ARR_INSEE              = df_data$ARR_INSEE,
                           GEOM_WKT               = df_data$wkt,
                           GEOM_SOURCE            = producteur,
                           `_TYPE`                = df_data$type,
                           `_EMPRISE_DESIGNATION` = df_data$name)
  df_data
}