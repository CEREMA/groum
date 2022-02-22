read_arrete <- function(inputFile) {
  read.csv(inputFile, sep=",", header = TRUE, encoding = "UTF-8")
}

export_gpkg_by_vehicles <- function(f, outputDir) {
  
  f$file_name <- f %>% format_vehicule %>% pull(VEHICULE) %>% {gsub(" ", "-", .)} %>% {glue("{.}.gpkg")}
  file_names <- unique(f$file_name)
  
  for(elt in file_names) {
    f.sel <- f %>% filter(file_name == elt)
    export_gpkg(f.sel, file.path(outputDir, elt))
  }
}

export_gpkg <- function(f, outputFile) {
  
  if(length(grep("POLYGON", st_geometry_type(f))) == 0) {
    message(">> Export de ", outputFile)
    st_write(f, outputFile, delete_dsn = TRUE)
  } else {
    outputLinePath <- gsub(".gpkg$", "-lines.gpkg", outputFile)
    message(">> Export de ", outputLinePath)
    f.lines <- f[grep("LINESTRING", st_geometry_type(f)), ]
    st_write(f.lines, outputLinePath, delete_dsn = TRUE)
    
    outputPolygonPath <- gsub(".gpkg$", "-polygons.gpkg", outputFile)
    message(">> Export de ", outputPolygonPath)
    f.polygons <- f[grep("POLYGON", st_geometry_type(f)), ]
    st_write(f.polygons, outputPolygonPath, delete_dsn = TRUE)
  }
}

na_empty <- function(df) {
  df[is.na(df)] <- ''
  df
}

# update_file_sf <- function(df, sf_data, producteur) {
#   m <- match(df$EMPRISE_DESIGNATION, sf_data$name)
#   sf_data <- sf_data[m, ]
#   sf_data <- df %>% update_file(ARR_INSEE            = sf_data$ARR_INSEE,
#                                 GEOM_WKT             = sf_data$wkt,
#                                 GEOM_SOURCE          = producteur,
#                                 _TYPE                = sf_data$type,
#                                 _EMPRISE_DESIGNATION = sf_data$name)
#   sf_data
# }

get_insee_from_libelle <- function(libelle, comms) {
  if(grepl("^.*([013-9]\\d|2[AB1-9])\\d{3}.*$", libelle)) {
    code_insee <- gsub("^.*((?:[013-9]\\d|2[AB1-9])\\d{3}).*$", "\\1", libelle)
  } else if(grepl("^Commune.*|^commune.*", libelle)) {
    nom_comm <- gsub("(?:C|c)ommune\\s(?:d'|d’|de\\s)?(.*)", "\\1", libelle)
    code_insee <- get_code_insee_from_nom(nom_comm, comms)
  } else if(grepl("^Ville.*|^ville.*", libelle)) {
    nom_comm <- gsub("^(?:V|v)ille\\s?(?:d'|d’|de)?(.*)$", "\\1", libelle)
    code_insee <- get_code_insee_from_nom(nom_comm, comms)
  } else {
    return()
  }
  code_insee
}

get_wkt_from_insee <- function(code_insee, comms) {
  url <- glue("https://geo.api.gouv.fr/communes/{code_insee}?format=geojson&geometry=contour&fields=geometry")
  coords <- fromJSON(url)$geometry$coordinates[1,,]
  geometry <- st_polygon(list(coords)) %>% st_sfc %>% st_set_crs(4326)
  wkt <- geometry %>% st_as_text()
  
  list(code_insee = code_insee, wkt = wkt, geometry = geometry)
}

get_slc_field_values <- function(the_field) {
  if(the_field %in% avec_proposition_referentiel) {
    value <- get_referentiel_from_csv(the_field)
  } else {
    value <- get_referentiel_from_schema(s, the_field)
  }
  id <- glue("slc_{the_field}")
  selectInput(id, NULL, choices = value, multiple = TRUE)
}

reencode <- function(md) {
  # ENCODAGE UTF-8 (OU PAS)
  if(Sys.getenv("R_CONFIG_ACTIVE") != "shinyapps") {
    message(">> Utilisation en local")
    md <- stri_encode(md, from = "UTF-8", to = "UTF-8")
  } else {
    message(">> Utilisation en remote sur shinyapps")
  }
  md
}

bbox_as_sf <- function(f) {
  f %>% st_bbox() %>% st_as_sfc
}

find_cote <- function(f) {
  bb <- f %>% bbox_as_sf %>% st_set_crs(4326) %>% st_transform(2154) %>%  st_bbox
  w <- bb$xmax - bb$xmin
  h <- bb$ymax - bb$ymin
  max(c(h, w))
}

find_zoom <- function(f) {
  cote <- find_cote(f)
  
  w1 <- which(f_zooms$largeur < cote) %>% tail(1)
  w2 <- which(f_zooms$largeur > cote) %>% tail(1)
  
  if(length(w1) == 0) return(max(f_zooms$zoom))
  if(length(w2) == 0) return(min(f_zooms$zoom))
  
  zoom1 <- f_zooms$zoom[w1]
  zoom2 <- f_zooms$zoom[w2]
  
  max(c(zoom1, zoom2))
}

create_table <- function(df) {
  df <- df %>% 
    make_data_frame %>%
    mutate(GEOM_WKT_display = paste(substr(GEOM_WKT, 1, 50), '...')) %>%
    dplyr::select(
           SOURCE      = EMPRISE_DESIGNATION_,
           DESTINATION = EMPRISE_DESIGNATION,
           type        = type,
           GEOM_WKT    = GEOM_WKT_display)
}

geocode <- function(url, sf_rues, libelles, producteur, mode = "distance") {
  message(">> Mode choisi : ", mode)
  withProgress(message = 'Chargement en cours...', value = 0, {
    
    if(is.null(sf_rues)) {
      incProgress(1/2, detail = "Téléchargement des rues")
      sf_rues <- read_streets(url, producteur)
      sf_rues$name <- sf_rues$name %>% stri_encode("UTF-8", "UTF-8")
    }
    
    incProgress(2/2, detail = "Géocodage du fichier")
    message(">> Géocodage du fichier")
    res <- get_rues(sf_rues, 
                    libelles = libelles,
                    mode,
                    comms = TRUE)
  })
  
  return(list(df_data = res$df_data, 
              sf_data = res$sf_data,
              sf_rues = sf_rues))
}

get_region_from_code_insee <- function(the_code_insee) {
  catalogue %>% filter(code_insee == the_code_insee) %>% pull(region)
}

# update_file <- function(df, ARR_INSEE, `_EMPRISE_DESIGNATION`, GEOM_WKT, GEOM_SOURCE, `_TYPE`, geometries = NULL) {
#   
#   df2 <- df
#   
#   df2$GEOM_WKT <- GEOM_WKT
#   df2$ARR_INSEE <- ARR_INSEE
#   df2$EMPRISE_DESIGNATION <- df$EMPRISE_DESIGNATION
#   df2[["_EMPRISE_DESIGNATION"]] <- df[["_EMPRISE_DESIGNATION"]]
#   df2$GEOM_SOURCE <- GEOM_SOURCE
#   df2[["_TYPE"]] <- df[["_TYPE"]]
#   
#   if(!is.null(geometries)) {
#     st_geometry(df2) <- geometries
#   }
#   
#   df2
# }

get_slc_region <- function(catalogue, the_producteur) {
  regions  <- catalogue %>% filter(producteur == the_producteur) %>% pull(region) %>% unique
  noms_regions <- regions %>% as.character
  regs <- c("", noms_regions)
  names(regs) <- c("Région", noms_regions)
  regs
}

get_slc_ville <- function(df, the_producteur, the_region) {
  df2 <- df %>% 
    filter(producteur == the_producteur & region  == the_region) %>% 
    dplyr::select(url, code_insee, nom_comm)
  
  # Build UI
  villes <- df2$url
  names_villes <- sprintf("%s (%s)", df2$nom_comm, df2$code_insee)
  o <- order(names_villes)
  
  # Tri
  villes <- villes[o]
  names_villes <- names_villes[o]
  
  # Ajout de l'élément vide
  villes <- c("", villes)
  names(villes) <- c("Commune", names_villes)
  
  villes
}

get_catalogue <- function(jsonlite, fromJSON) {
  url <- "https://api.github.com/repos/mrajerisoncerema/streets-as-geojson/git/trees/master?recursive=1"
  res <- jsonlite::fromJSON(url)
  paths <- res$tree$path
  
  # Filtre des URLs
  w <- grep("^(OSM|IGN).*geojson", paths)
  paths <- paths[w]
  
  url <- glue("https://raw.githubusercontent.com/mrajerisonCerema/streets-as-geojson/master/{paths}")
  producteur <- gsub("^((?:OSM|IGN))/.*$", "\\1", paths)
  region <- gsub("^(?:OSM|IGN)/(.*)/[0-9]{5}.*$", "\\1", paths)
  gsub("(?:OSM|IGN)/(.*)/.*", "\\1", "OSM/ILE DE FRANCE/1300-test.geojson")
  code_insee <- gsub("^.*/([0-9]{5}).*$", "\\1", paths)
  nom_comm <- gsub("^.*/[0-9]{5}-(.*)\\.geojson$", "\\1", paths)
  
  url <- sapply(url, URLencode)
  
  df <- data.frame(url, 
                   producteur, 
                   region, 
                   code_insee, 
                   nom_comm)
  df
}

add_lines <- function(proxy, f, label) {
  
  bb <- st_bbox(f)
  lng1 <- as.numeric(bb$xmin)
  lng2 <- as.numeric(bb$xmax) 
  lat1 <- as.numeric(bb$ymin)
  lat2 <- as.numeric(bb$ymax)
  
  proxy %>% 
    clearShapes %>% 
    addPolylines(data = f, 
                 label = label,
                 color = LINE_COLOR,
                 opacity = 0.7) %>% 
    flyToBounds(lng1, lat1, lng2, lat2, options = leafletOptions(padding = c(5, 5)))
}

load_libraries <- function(libraries) {
  for(lib in libraries) suppressMessages(library(lib, character.only = T))
}

fly_to_comm <- function(proxy, code_comm) {
  f <- comms %>% filter(INSEE_COM == code_comm)
  bb <- st_bbox(f) %>% as.numeric
  # message(">> flyToBounds1 ", paste(bb, collapse = ", "))
  # bb <- as.numeric(bb_fr)
  # message(">> flyToBounds2 FR ", paste(bb, collapse = ", "))
  proxy %>% flyToBounds(bb[1], bb[2], bb[3], bb[4])
}

fly_to_region <- function(proxy, nom_region) {
  f <- f.regs %>% filter(NOM_REG_M == nom_region)
  bb <- st_bbox(f) %>% as.numeric
  message(">> flyToBounds ", paste(bb, collapse = ", "))
  proxy %>% flyToBounds(bb[1], bb[2], bb[3], bb[4])
}

get_bloc_rue <- function(data) {
  div(data$name, 
      ifelse(data$union, sprintf("(%d brins ont été fusionnés)", data$n), ""), 
      tags$br(), 
      tags$div(data$wkt,
               class="result_wkt")
  )
}

get_bloc_rues <- function(data) {
  lapply(1:nrow(data), function(i) get_bloc_rue(data[i, ]))
}

get_image_dimensions <- function(f, width = 1000) {
  bb <- st_bbox(f)
  ratio <- (bb[4] - bb[2]) / (bb[3] - bb[1])
  height <- width * ratio
  return(c(width, height))
}

get_map <- function(f, zoom, output_image) {
  
  # TILES
  nc <- get_tiles(x = f, 
                  provider = tile_provider, 
                  crop = TRUE, 
                  cachedir = tempdir(), 
                  verbose = TRUE,
                  zoom = zoom)
  
  # TEXTS
  coords <- st_coordinates(st_centroid(f))
  long <- coords[, 1]
  lat <- coords[, 2]
  texts <- data.frame(id = 1:nrow(f), 
                      name = f$name, 
                      long, 
                      lat)
  
  # Convert nc to raster
  r <- stack(nc)
  
  # Dimensions
  dimensions <- get_image_dimensions(f)
  w <- dimensions[1]
  h <- dimensions[2]
  
  # ggplot
  ggRGB(r, r=1, g=2, b=3) +
    geom_sf(data = f, color = LINE_COLOR, lwd = 0.5) +
    theme_minimal() +
    geom_shadowtext(data = texts, aes(x = long, y = lat),
                    label = texts$id,
                    check_overlap = TRUE,
                    size = 1,
                    color = LINE_COLOR,
                    bg.colour='white',
                    bg.r = 0.2) +
    theme(
      axis.line=element_blank(),axis.text.x=element_blank(),
      axis.text.y=element_blank(),axis.ticks=element_blank(),
      axis.title.x=element_blank(),
      axis.title.y=element_blank(),legend.position="none",
      panel.background=element_blank(),panel.border=element_blank(),panel.grid.major=element_blank(),
      panel.grid.minor=element_blank(),plot.background=element_blank()) +
    theme(plot.margin=grid::unit(c(-2,0,-2,0), "mm"))
  
  message(">> Export de la carte ", output_image)
  ggsave(output_image, width = w, height = h, units = "px")
}

# Transforme la donnée en data frame
make_data_frame <- function(f) {
  if("geometry" %in% names(f)) {
    f %>% data.frame %>% dplyr::select(-geometry)
  } else {
    f
  }
}

get_url <- function(catalogue, the_code_insee, the_producteur = "OSM") {
  url <- catalogue %>% 
    filter(code_insee == the_code_insee & producteur == the_producteur) %>% 
    pull(url)
  message(">> URL : ", url)
  url
}

# Crée l'URL depuis le nom de la région, le code et le nom de la commune
OLD_get_url <- function(code_insee, producteur = "IGN") {
  nom_comm   <- code_insee %>% get_city_from_insee
  nom_region <- code_insee %>% get_region
  nom_region <- gsub("-", " ", gsub("'", " ", nom_region))
  # url <- glue("https://github.com/mrajerisonCerema/streets-as-geojson/blob/master/{nom_region}/{code_insee}-{nom_comm}.geojson?raw=true")
  # url <- "https://raw.githubusercontent.com/mrajerisonCerema/streets-as-geojson/master/PROVENCE ALPES COTE D AZUR/13001-Aix-en-Provence.geojson"
  # url <- "https://raw.githubusercontent.com/mrajerisonCerema/streets-as-geojson/master/PROVENCE%20ALPES%20COTE%20D%20AZUR/13001-Aix-en-Provence.geojson"
  url <- glue("https://raw.githubusercontent.com/mrajerisonCerema/streets-as-geojson/master/{producteur}/{nom_region}/{code_insee}-{nom_comm}.geojson")
  url <- URLencode(url)
  message(">> URL : ", url)
  url
}

# Récupère le code commune depuis une URL
get_commune_from_url <- function(url) {
  # url <- "https://raw.githubusercontent.com/mrajerisonCerema/streets-as-geojson/master/PROVENCE%20ALPES%20COTE%20D%20AZUR/13001-Aix-en-Provence.geojson"
  code_insee <- gsub(".*/([0-9]{5})-(.*)\\.geojson", "\\1", url)
  nom_comm <- gsub(".*/([0-9]{5})-(.*)\\.geojson", "\\2", url)
  lib_comm <- glue("{nom_comm} ({code_insee})")
  fichier_geojson <- glue("{code_insee}-{nom_comm}.geojson")
  
  return(c(code_insee, nom_comm, lib_comm, fichier_geojson))
}

get_region <- function(code_insee) {
  dep <- substr(code_insee, 1, 2)
  nom_region <- comms %>% filter(INSEE_DEP == dep) %>% pull(NOM_REG) %>% unique %>% as.character
  nom_region
}

# Utilisé pour alimenter la liste des villes
OLD_get_villes <- function(nom_region, producteur) {
  
  comms <- get_communes(df_regs, nom_region, producteur)
  urls <- comms$urls
  # urls <- glue("https://github.com/mrajerisonCerema/streets-as-geojson/blob/master/{nom_region}/{files}?raw=true")
  # urls <- glue("https://raw.githubusercontent.com/mrajerisonCerema/streets-as-geojson/master/{nom_region}/{files}")
  urls <- gsub(" ", "%20", urls)
  
  villes <- urls
  villes <- c(villes)
  names_villes <- sprintf("%s (%s)", comms$noms_coms, comms$codes_insees)
  o <- order(names_villes)
  villes <- villes[o]
  names_villes <- names_villes[o]
  
  villes <- c("", villes)
  names(villes) <- c("Commune", names_villes)
  
  villes
  
}

get_code_region <- function(nom_region) {
  code_region <- f.regs %>% filter(NOM_REG_M == nom_region) %>% pull(INSEE_REG)
  code_region
}

OLD_get_regions <- function(producteur = "IGN") {
  # url <- "https://api.github.com/repos/mrajerisoncerema/streets-as-geojson/git/trees/master"
  url <- "https://api.github.com/repos/mrajerisoncerema/streets-as-geojson/git/trees/master/{producteur}"
  url <- "https://api.github.com/repos/mrajerisoncerema/streets-as-geojson/git/trees/master"
  res <- jsonlite::fromJSON(url)
  w <- which(res$tree$path == producteur)
  sha <- res$tree$sha[w]
  url <- glue("https://api.github.com/repos/mrajerisoncerema/streets-as-geojson/git/trees/{sha}")
  res <- jsonlite::fromJSON(url)
  w <- grep("[A-Z]\\s", res$tree$path)
  regions <- res$tree$path[w]
  shas <- res$tree$sha[w]
  data.frame(regions, shas)
}

get_communes <- function(df, nom_region, producteur = "IGN") {
  
  # Get files
  sha <- df %>% filter(regions == nom_region) %>% pull(shas)
  url <- glue("https://api.github.com/repos/mrajerisoncerema/streets-as-geojson/git/trees/{sha}")
  res <- jsonlite::fromJSON(url)
  files <- res$tree$path
  
  # Get URLSs
  urls <- glue("https://raw.githubusercontent.com/mrajerisonCerema/streets-as-geojson/master/{producteur}/{nom_region}/{files}")
  urls <- sapply(urls, URLencode)
  
  # Get commune and code_insee
  regex <- "([0-9]{5})-(.*)\\.geojson"
  codes_insees <- gsub(regex, "\\1", files)
  noms_coms <- gsub(regex, "\\2", files)
  
  data.frame(codes_insees, noms_coms, urls)
}

detectBestString <- function(str, libelles) {
  
  out = vector(mode="list")
  for (i in 1:length(libelles)) {
    
    libelle = libelles[i]
    
    # SPLIT
    if (str_detect(libelle, "\\*")) {
      v = str_split(libelle, "\\*")[[1]]
    } else {
      v = libelle
    }
    
    # DISTANCES
    s = sapply(v, function(x) stringdist(str, x, method="dl"))
    
    # MEILLEUR CANDIDAT DANS LA CHAINE (UTILE SI SPLIT)
    d = min(s)
    w = which.min(s)
    out[[i]] = data.frame(libelle, d, w)
  }
  df = do.call(rbind, out)
  
  # MIN DISTANCE
  res = df[which.min(df$d), ]
  
  return(res)
}

# Méthode permettant de trouver les rues qui contiennent 
# un des éléments compris dans une chaîne de caractères
# Par exemple, "Philippe Solari" va être trouvé dans "Avenue Philippe Solari" 
# avec un score de 2 puisque Philippe et Solari sont tous deux trouvés
# (Avenue est supprimé de la recherche)
# "Rue Philippe Rollin" aura un score de 1
# Ainsi, si n_result est égal à 1, le score le plus haut sera retourné
# et "Avenue Philippe Solari" constituera la réponse
find_streets_containing <- function(sf_rues, rue, n_result) {
  message(">> Mode : find streets containing")
  sf_rues_names <- unique(sf_rues$name)
  clean1 <- clean_street_names(rue)
  clean2 <- clean_street_names(sf_rues_names)
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
    head(n_result) %>% 
    mutate(source = rue) %>% 
    mutate(name = sf_rues_names[.$index])
  
  return(res)
}

get_city_from_insee <- function(code_insee) {
  w <- match(code_insee, comms$INSEE_COM)
  nom_comm <- comms$NOM_COM[w]
  nom_comm
}

get_code_insee_from_nom <- function(nom_comm, comms) {
  w <- match(nom_comm, comms$NOM_COM)[1] # On ne retient que le premier
  code_insee <- comms$INSEE_COM[w]
  if(is.na(code_insee)) return()
  code_insee
}

# get_insee_from_city <- function(city) {
#   city <- toupper(city)
#   w <- match(city, geofla$NOM_COMM)
#   code_insee <- geofla$INSEE_COM[w] %>% as.character
#   code_insee
# }

get_pattern_for_field <- function(s, the_field) {
  res <- get_field_from_schema(s, the_field)
  pattern <- res$constraints$pattern
  return(pattern)
}

get_pattern_from_values <- function(values) {
  sprintf("(?:(?:^|\\\\|)(%s))+$", paste(values, collapse="|"))
}

get_referentiel_from_csv <- function(the_field) {
  url <- glue("https://raw.githubusercontent.com/CEREMA/schema-arrete-circulation-marchandises/master/referentiels/{the_field}.csv")
  
  destfile <- file.path("data", glue("{the_field}.csv"))
  download.file(url, destfile = destfile)
  s <- readLines(destfile) %>% 
    stri_encode(from = "ISO-8859-1", to = "UTF-8")
  s
}

get_field_from_schema <- function(s, the_field) {
  res <- s$fields %>% filter(name == the_field)
  return(res)
}

get_referentiel_from_schema <- function(s, the_field) {
  # fields <- sapply(s$fields, function(x) x$name)
  # w <- which(fields == the_field)
  # pattern <- s$fields[w][[1]]$constraints$pattern
  
  pattern <- get_pattern_for_field(s, the_field)
  pattern <- gsub("\\(\\?\\:\\(\\?\\:\\^\\|\\\\\\|\\)\\((.*)\\)\\)\\+\\$", "\\1", pattern)
  values <- strsplit(pattern, "\\|")[[1]]
  
  return(values)
}

# load_rues <- function(city, insee = FALSE) {
#   
#   if(insee) {
#     code_insee <- city
#     w <- match(code_insee, geofla$INSEE_COM)
#     city <- geofla$NOM_COMM[w] %>% tolower()
#   } 
#   
#   q <- sprintf("select * from \"rues-paca\"  where noms_coms LIKE '%s' and name is not NULL", city)
#   f <- st_read("data/rues-paca.gpkg", layer = "rues-paca", query = q)
#   f
# }

split_streets <- function(noms_rues_s) {
  noms_rues <- strsplit(noms_rues_s, ",")[[1]]
  noms_rues <- gsub("^\\s", "", noms_rues)
  noms_rues
}

get_libelle <- function(s) {
  if(is.na(s) | s == "" | s == "NC") {
    s <- "Tous"
  } else {
    s
  }
  s
}

firstup <- function(x) {
  substr(x, 1, 1) <- toupper(substr(x, 1, 1))
  x
}

get_first <- function(s) {
  if(all(is.na(s))) return()
  
  s %>% unique %>% na.omit %>% head(1)
}

display <- function(s) {
  if(is.null(s)) return(FALSE)
  !is.na(s) & s != "NC" & s != "" & (length(s) > 0)
}

format_code_insee <- function(code_insee) {
  str_pad(code_insee, 5, side = "left", "0")
  
}

md_rues <- function(f) {
  rues <- glue("\n\n- ({f$id}) {f$name}")
  bloc_rues <- rues %>% paste(., collapse="\n")
  bloc_rues
}

write_Rmd <- function(arrete, map, output_file = "arrete.Rmd") {
  md1 <- arrete$md %>% paste(collapse="")
  md2 <- map$md %>% paste(collapse="")
  md <- paste(md1, md2, collapse="")
  writeLines(md, output_file, useBytes = T)
}

md_map <- function(f, zoom_increase) {
  
  f <- as_spatial(f)
  
  if(is.null(f)) return()
  
  # incProgress(2/2, detail = "Création de la carte")
    
  f <- f %>% distinct(EMPRISE_DESIGNATION, geometry) %>% 
    dplyr::select(name = EMPRISE_DESIGNATION) %>% 
    arrange(name) %>% 
    mutate(id = 1:nrow(.))
  
  md1 <- c()
  
  # Zoom
  zoom <- find_zoom(f)
  zoom <- zoom + zoom_increase
  ifelse(zoom > 19, 19, zoom)  
  ifelse(zoom < 14, 14, zoom)  
  
  # Create map
  output_image <- "files/map.png"
  get_map(f, zoom, output_image)
  
  # Add map to markdown
  md1 <- c(md1, "## Annexes\n")
  md1 <- c(md1, "### Carte\n")
  # md <- c(md, glue("![]({output_image})"))
  md1 <- c(md1, glue("<div><img src='{output_image}' width=2000 style='width:100%'></img></div>"))
  # md <- c(md, "![](files/map.png){width=100%}")
  md1 <- c(md1, "<div style='text-align:center'>Fonds de carte : IGN PLAN V2 ©</div>")
  
  # Liste des rues
  md2 <- md_rues(f)
  
  # md final
  md <- paste(c(md1, md2), collapse="\n")
  
  list(md = md, zoom = zoom)
}

GEOM_WKT_vide <- function(f) {
  if(!("GEOM_WKT" %in% names(f))) return(TRUE)
  all(is.na(f$GEOM_WKT))
}

OLD_read_remote_rds_for_commune <- function(url, output_dir = "downloads") {
  # url <- "https://github.com/mrajerisonCerema/streets-as-geojson/blob/master/PROVENCE ALPES COTE D AZUR/13001-Aix-en-Provence.rds?raw=true"
  fichier_rds <- gsub(".*/([0-9]{5}.*)\\?.*", "\\1", url)
  output_file <- file.path("downloads", fichier_rds)
  download.file(url, output_file, mode = "wb")
  # output_file <- "test.rds"
  # download.file("https://github.com/mrajerisonCerema/streets-as-geojson/blob/master/PROVENCE%20ALPES%20COTE%20D%20AZUR/13001-Aix-en-Provence.rds?raw=true", "test.rds")
  f <- readRDS(output_file)
  return(f)
}