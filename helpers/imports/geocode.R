as_spatial <- function(df, geom_col = "GEOM_WKT") {
  if(!(geom_col %in% names(df))) {
    the_col <- grep("GEOM_WKT", names(df))
    if(length(the_col) == 0) {
      stop("La colonne ", geom_col, " n'existe pas. Avez-vous voulu dire ", the_col, " ?")
    } else {
      stop("La colonne ", geom_col, " n'existe pas")
    }
  } else {
    if(all(is.na(df[[geom_col]])) | all(df[[geom_col]] == "")) {
      stop("La colonne ", geom_col, " est vide")
    } else {
      w <- which(df[[geom_col]] != "")
      if(length(w) == 0) stop("La colonne ", geom_col, " est vide")
      df <- df[w, ]
      st_geometry(df) <- st_as_sfc(df[[geom_col]])
      df %>% st_set_crs(4326)
    }
  }

}

CSV2GPKG <- function(input, output, geom = "GEOM_WKT") {
  
  # Lecture du fichier
  df <- read_arrete(input)
  
  # Conversion en spatial
  sf.data <- as_spatial(df, geom_col = geom)
      
  # Export
  export_gpkg(sf.data, output)
}

geocodeCSV <- function(input, streets, output, communes = NA) {
  if(!file.exists(input)) {
    stop(input, " n'existe pas")
  }
  
  if(!dir.exists(dirname(output))) {
    stop("Dossier ", dirname(output), " inexistant")
  }
  
  # On lit le fichier d'entrée
  df <- read.csv(input, header = TRUE, sep = ",", encoding = "UTF-8")
  
  # On récupère le fichier de rues
  if(!file.exists(input)) {
    stop("Le fichier de rues ", streets, " n'existe pas")
  }
  sf_rues <- read_streets(streets)
  
  # On apparie
  res <- get_rues(sf_rues, 
                  rues = df$EMPRISE_DESIGNATION, 
                  communes = communes)
  
  # On met à jour le fichier initial
  df2 <- df %>% update_file(res = res)
  
  # On l'exporte
  message(">> Export de ", output)
  write.csv(df2, output, fileEncoding = "UTF-8", row.names = FALSE)
}

# Mode = "distance" (lenvenshtein) ou "inclusion"
get_rues <- function(sf_rues, rues, mode = "distance", communes = NA) {
  # message(">> Recherche des rues dont les noms sont les plus proches...")
  
  out <- vector(mode="list")
  for(i in 1:length(rues)) {
    rue <- rues[i]
    res <- get_rue(sf_rues, 
                   rue = rue, 
                   mode = mode, 
                   communes = communes)
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

get_commune <- function(rue, comms) {
  
  libelle <- rue
  
  # On récupère le code INSEE depuis la rue
  code_insee <- get_insee_from_libelle(libelle, comms)
  
  # Si le code INSEE est nul, alors on renvoie un sf data frame vide
  if(is.null(code_insee)) {
    res <- empty_sf(libelle)
    return(res)
  }
  
  # On récupère la chaîne WKT correspondant au code commune
  res <- get_wkt_from_insee(code_insee, 
                            comms)
  
  # Si le code INSEE n'est pas dans le libellé de rue, alors on reformate l'entrée
  if(!grepl(res$code_insee, libelle)) {
    libelle <- glue("{libelle} ({code_insee})")
  }
  
  # On crée l'objet résultat
  res <- data.frame(name  = libelle, 
                    type  = "City",
                    union = NA, 
                    n     = NA,
                    wkt   = res$wkt,
                    distance = NA
                    ) %>% 
    st_as_sf(wkt = "wkt") %>% 
    rename(geometry = wkt) %>% 
    mutate(wkt = res$wkt) %>% 
    st_set_crs(4326) %>% 
    select(name, type, union, n, wkt, geometry)
  
  # Ajout de la colonne géométrie
  # res$geometry <- st_geometry(res)
  
  return(res)
  # return(list(df_data = as.data.frame(res) %>% drop_geometry_column, 
  #             sf_data = res))
}

get_rue <- function(rue, sf_rues, mode = "distance", communes = NA) {
  
  # Commune ou rue ?
  # Récupération de la commune
  if(is_commune(rue)) {
    if(!is.na(communes)) {
      if(!file.exists(communes)) {
        message(">> Le fichier communes ", communes, "n'a pas été trouvé, donc il n'est pas possible de géocoder la commune.")
        data <- empty_sf(rue)
      } else {
        message(">> Lecture du fichier ", communes)
        comms <- st_read(communes)
        data <- get_commune(rue, 
                            comms = comms) # !! renommer la fonction
      }
    } else {
      message(">> Le fichier communes n'a pas été spécifié. Nous ne rajouterons donc pas la géométrie de la commune.")
      data <- empty_sf(rue)
    }
  # Récupération de la rue
  } else  {
    # Choix de la fonction
    if(mode == "distance") {
      thefunction <- find_similar_streets
    } else {
      thefunction <- find_streets_containing
    }
    
    # On cherche la rue la plus ressemblante
    res <- thefunction(sf_rues, 
                       rue = as.character(rue),
                       n = 1)
    
    # On en récupère la chaîne WKT
    data <- get_wkt(rue     = as.character(res$name),
                    sf_rues = sf_rues) %>% 
      mutate(distance = res$distance)
  }

  return(data)
  # return(list(df_data = as.data.frame(data) %>% drop_geometry_column, 
  #             sf_data = data))
}

find_similar_streets <- function(sf_rues, rue, n = 5) {
  
  # message(">> Find similar Streets")
  
  # Distance de levenshtein entre les rues
  d <- stringdist(clean_street_names(rue), 
                  clean_street_names(sf_rues$name), 
                  method = "dl")
  
  # Récupération de la meilleure note pour la rue
  df <- data.frame(name = sf_rues$name, 
                   distance = d,
                   osm_id = sf_rues$osm_id) %>% 
    group_by(name) %>% 
    summarize(osm_ids = paste(osm_id, collapse=","), 
              distance = mean(distance), 
              n_streets = n()) %>% 
    data.frame %>% 
    # On trie selon la note
    arrange(distance) %>% 
    # On prend les n résultats
    head(n)
  
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
  # message(">> read_streets (lecture des rues) ", inputFile)
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

get_wkt <- function(sf_rues, rue = NA, the_index = NA) {
  
  # On se base sur l'OSM ID si pas de nom de rue
  # Pas de fusion des géométries
  if(is.na(rue)) {
    n <- 1
    f.sel <- sf_rues %>% filter(index == the_index)
    geom <- f.sel  %>% st_geometry
    wkt <- geom %>% st_as_text()
    nom_rue <- f.sel$name
    union <- FALSE
  }
  
  # On se base sur name
  # Fusion des géométries
  if(is.na(the_index)) {
    w <- which(sf_rues$name == rue)
    f.sel <- sf_rues %>% slice(w)
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
  }
  
  res <- data.frame(name  = rue, 
                    type  = "Street",
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