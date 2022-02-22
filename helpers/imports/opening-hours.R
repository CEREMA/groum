explain_oh_unit <- function(s) {
  
  md <- NULL
  
  # JOURS
  res_jour <- process_jour(s)
  md <- c(md, res_jour)
  
  # HEURES
  res_heure <- process_heure(s)
  md <- c(md, res_heure)
  
  md <- paste(md, collapse=" ")
  
  return(md)
}

explain_oh <- function(s) {
  
  if(grepl(";", s)) {
    # Séparation des chaînes par le ;
    s2 <- strsplit(s, ";")[[1]]
    # Suppression des espaces
    s2 <- sapply(s2, trimws)
    # Traduction de la chaîne
    s2 %>% sapply(explain_oh_unit) %>% paste(collapse=" ainsi que ")
  } else {
    s %>% trimws %>% explain_oh_unit
  } 
}

process_jour <- function(s) {
  
  jours <- c("Lundi"              = "Mo",
             "Mardi"              = "Tu",
             "Mercredi"           = "We",
             "Jeudi"              = "Th",
             "Vendredi"           = "Fr",
             "Samedi"             = "Sa",
             "Dimanche"           = "Su",
             "Jours fériés"       = "PH",
             "Vacances scolaires" = "SH")
  
  # 24/7
  if(s == "24/7") {
    return("tous les jours et toute la journée")
  }
  
  # PH
  if(s == "PH OFF") {
    return("pas pendant les jours fériés")
  }
  
  # SH
  if(s == "SH OFF") {
    return("pas pendant les vacances scolaires")
  }
  
  # Jours de la semaine
  regex_jours <- jours %>% paste(collapse="|")
  regex_jours <- glue("{regex_jours}|-|,")
  regex_jours <- glue("((?:{regex_jours}))\\s.*")
  res <- gsub(regex_jours, "\\1", s)
  
  explain_jour(res)
}

explain_horaire <- function(s) {
  if(grepl(",", s)) {
    explain_deux_periodes(s)
  } else {
    explain_une_periode(s)
  }
}

as_duration <- function(s) {
  # as_duration("00:00")
  # as_duration("06:00")
  # as_duration("00:30")
  # as_duration("06:30")
  
  s <- trimws(s, which = "both")
  
  s2 <- strsplit(s, ":")
  
  heures  <- as.numeric(s2[[1]][1]) * 3600
  minutes <- as.numeric(s2[[1]][2]) * 60
  
  v <- as.duration(heures + minutes)
  
  return(v)
}

traduire_heure_minutes <- function(s) {
  # traduire_heure_minutes("00:00")
  # traduire_heure_minutes("00:15")
  # traduire_heure_minutes("00:30")
  # traduire_heure_minutes("06:00")
  # traduire_heure_minutes("10:00")
  
  traduire_minutes <- function(minutes, traduire = FALSE) {
    if(minutes == "00") {
      minutes <- ""
    } else if(minutes == "15" & traduire) {
      minutes <- " et quart"
    } else if(minutes == "30" & traduire) {
      minutes <- " et demie"
    }
    return(minutes)
  }
  
  s <- trimws(s, which="both")
  
  res <- strsplit(s, ":")[[1]]
  heures <- res[1]
  minutes <- res[2]
  
  if(heures %in% c("00", "24")) {
    heures <- "Minuit"
    minutes <- traduire_minutes(minutes, traduire = TRUE)
  } else if(heures == "12") {
    heures <- "Midi"
    minutes <- traduire_minutes(minutes, traduire = TRUE)
  } else {
    # On enlève le premier zéro
    heures <- gsub("^0", "", heures)
    heures <- glue("{heures}h")
    minutes <- traduire_minutes(minutes, traduire = FALSE)
  }
  
  res <- glue("{heures}{minutes}")
  return(res)
}

get_periodes <- function(s) {
  # get_periodes("11:00-19:00")
  res <- strsplit(s, "-")[[1]]
  
  from <- res[1] %>% trimws(which="both")
  to   <- res[2] %>% trimws(which="both")
  
  return(c(from, to))
}

explain_une_periode <- function(s) {
  # explain_une_periode(s = "13:00-19:00")
  
  if(grepl("-", s)) {
    
    s <- get_periodes(s)
    
    return(paste("entre", s[1] %>% traduire_heure_minutes(), 
                 "et",    s[2] %>% traduire_heure_minutes()))
    
  } else if (grepl("+$", s)) {
    
    from <- gsub("(.*)\\+", "\\1", s) %>% traduire_heure_minutes()
    
    return(paste("à partir de", from))
  }
}

explain_jour <- function(res) {
  # explain_jour("Mo,Tu,We")
  # explain_jour("Mo,We")
  # explain_jour("Mo-We")
  # explain_jour("Su,PH")
  # explain_jour("Su,SH")
  
  jours <- c("Lundi"="Mo", 
             "Mardi"="Tu",
             "Mercredi"="We",
             "Jeudi"="Th",
             "Vendredi"="Fr",
             "Samedi"="Sa",
             "Dimanche"="Su",
             "Dimanche"="Su",
             "Jours fériés"="PH",
             "Vacances scolaires"="SH"
  )
  
  if(grepl("-", res)) {
    res2 <- strsplit(res, "-")[[1]]
    from <- res2[1]
    to <- res2[2]
    from <- names(jours)[match(from, jours)]
    to <- names(jours)[match(to, jours)]
    paste("De", from, "à", to)
  } else if (grepl(",", res)) {
    liste_jours <- strsplit(res, ",")[[1]]
    m <- match(liste_jours, jours)
    liste_jours <- names(jours)[m]
    discontinued <- any(sapply(2:length(m), function(x) (m[x] - m[x-1]) > 1))
    if(discontinued) {
      paste("Le ", paste(liste_jours, collapse=", "))
    } else {
      from <- head(liste_jours, 1)
      to <- tail(liste_jours, 1)
      glue("De {from} à {to}")
    }
  }
}

explain_deux_periodes <- function(periode1, periode2) {
  # explain_deux_periodes(periode1 = "11:00-19:00", periode2 = "00:00-06:00")
  # explain_deux_periodes(periode1 = "11:00-19:00", periode2 = "22:00-06:00")
  # explain_deux_periodes(periode1 = "00:00-06:00", periode2 = "08:00-10:00")
  # explain_deux_periodes(periode1 = "00:00-06:00", periode2 = "22:00-00:00")
  # explain_deux_periodes(periode1 = "00:00-06:00", periode2 = "22:00-24:00")
  # explain_deux_periodes(periode1 = "00:00-06:00", periode2 = "22:00-10:00")
  
  # Traduction de chacune des périodes
  premiere_plage <- explain_une_periode(periode1)
  seconde_plage  <- explain_une_periode(periode2)
  
  # Début et fin de Période 1
  res1 <- get_periodes(periode1)
  from1 <- res1[1]
  to1   <- res1[2]
  
  # Début et fin de Période 2
  res2 <- get_periodes(periode2)
  from2 <- res2[1]
  to2   <- res2[2]
  
  # Lendemain ?
  lendemain <- FALSE
  
  # ex. 08:00-10:00, 22:00-00:00
  if(as_duration(to2) != 0) {
    
    # ex. 08:00-10:00, 00:00-11:00
    if(as_duration(from2) == 0) {
      lendemain <- TRUE
      
    # ex. 08:00-10:00, 24:00-11:00
    # ex. 08:00-10:00, 24:30-11:00
    } else if(as_duration(from2) >= as_duration("24:00")) {
      lendemain <- TRUE
    
    # ex. 08:00-10:00, 22:00-11:00
    } else if(as_duration(to2) < as_duration(from2)) {
        lendemain <- TRUE
    
    # ex. 08:00-10:00, 22:00-06:00
    } else if(as_duration(to2) < as_duration(from1)) {
      lendemain <- TRUE
      
    # ex. 08:00-10:00, 22:00-09:00
    } else if(as_duration(to2) < as_duration(to1)) {
      lendemain <- TRUE
    } 
  }
  
  lendemain_s <- ifelse(lendemain, "le lendemain", "")
  
  s3 <- glue("{premiere_plage} puis {seconde_plage} {lendemain_s}")
  
  return(s3)
}

format_date <- function(date) {
  
  # date <- "2021-07-03"
  date <- format(ymd(date), "%A %d %B %Y")
  # date <- "thursday 3 july 2021"
  
  jours <- c("Lundi"="Monday", 
             "Mardi"="Tuesday",
             "Mercredi"="Wednesday",
             "Jeudi"="Thursday",
             "Vendredi"="Friday",
             "Samedi"="Saturday",
             "Dimanche"="Sunday"
  )
  
  mois <- c("Janvier"="January", 
            "Février"="February",
            "Mars"="March",
            "Avril"="April",
            "Mai"="May",
            "Juin"="June",
            "Juillet"="July",
            "Août"="August",
            "Septembre"="September",
            "Octobre"="October",
            "Novembre"="November",
            "Décembre"="December"
  )
  
  for(i in 1:length(jours)) {
    date <- gsub(jours[i], names(jours)[i], date)
  }
  
  for(i in 1:length(mois)) {
    date <- gsub(mois[i], names(mois)[i], date)
  }
  
  date
  
}

process_heure <- function(s) {
  
  # ex. 08:00-10:00, ou 14:00-16:00
  heures_regex1 <- "[0-9]{2}:[0-9]{2}-[0-9]{2}:[0-9]{2}(?:,[0-9]{2}:[0-9]{2}-[0-9]{2}:[0-9]{2})?"
  heures_regex1 <- glue(".*\\s({heures_regex1})")
  
  # ex. 10:00+
  heures_regex2 <- "[0-9]{2}:[0-9]{2}\\+"
  heures_regex2 <- glue(".*\\s({heures_regex2})")
  
  # ex. 08:00-10:00, ou 14:00-16:00
  if(grepl(heures_regex1, s)) {
    
    res <- str_extract_all(s, "[0-9]{2}:[0-9]{2}-[0-9]{2}:[0-9]{2}")[[1]]
    
    if(length(res) == 1) {
      s <- explain_une_periode(res)
    } else if (length(res) == 2) {
      periode1 <- res[1]
      periode2 <- res[2]
      s <- explain_deux_periodes(periode1, periode2)
    }
    return(s)
    # ex. 10:00+
  } else if (grepl(heures_regex2, s)) {
    res <- gsub(heures_regex2, "\\1", s)
    explain_horaire(res)
  }
}