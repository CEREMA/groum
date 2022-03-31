renderHeader <- function(l) {
  tagList(
    tags$p(div(l$titre_arrete, style="text-transform:uppercase; font-weight:700;")),
    tags$p(tags$b("Référence de l'arrêté : "), l$arr_ref),
    tags$p(tags$b("Date de l'arrêté : "), l$arr_date),
    tags$p(tags$b("Objet de l'arrêté : "), l$arr_objet),
    tags$p(tags$b("Considérant : "), 
           tags$br(), 
           HTML(gsub("\\n", "<br>", l$arr_considerant))))
}

renderElement <- function(s, bgcolor) {
  if(!display(s)) return()
  tags$span(s, 
            style = glue("background-color:{bgcolor}; padding : 10px; border-radius:3px;"))
}

renderBody <- function(l) {
  
  bloc <- tagList()
  
  for(article in l$articles) {
    for(sous_article in article[[2]]) {
      for(motif in sous_article[[2]]) {
        for(vehicule in motif[[2]]) {
          
          bloc <- tagAppendChild(bloc, 
                                 tags$div(
                                   renderElement(article[[1]], "#c7c7c7"), 
                                   renderElement(sous_article[[1]], "#c7c7c7"),
                                   renderElement(vehicule[[1]], "#c7c7c7")
                                   , style="margin-bottom:20px;line-height:30px;"))
          
          for(modalite in vehicule[[2]]) {
            
            bgcolor <- ifelse(modalite[[1]] == "Autorise", "#9ce29c", "#ffbebe")

            bloc <- tagAppendChild(bloc, div(renderElement(modalite[[1]], bgcolor), 
                                             renderElement(motif[[1]], "#bed0e0"),
                                             style="margin-bottom:20px;"))
            
            for(periode in modalite[[2]]) {
              bloc <- tagAppendChild(bloc, tags$p((periode[[1]])))
              bloc_ul <- tags$ul()
              for(emprise in periode[[2]]) {
                bloc_ul <- tagAppendChild(bloc_ul, tags$li(emprise[[1]]))
              }
              bloc <- tagAppendChild(bloc, bloc_ul)
            }
          }
        }
      }
      bloc <- tagAppendChild(bloc, tags$hr())
    }
  }
  
  return(bloc)
}

renderArreteAsHtml <- function(f, header = TRUE, body = TRUE) {
  
  l <- arrete2List(f)
  
  bloc <- tagList()
  
  if(header) {
    header <- renderHeader(l)
    bloc <- tagAppendChild(bloc, header)
  }
  
  if(body) {
    body <- renderBody(l)
    bloc <- tagAppendChild(bloc, body)
  }
  
  bloc
}

get_titre_arrete <- function(f) {
  COLL_NOM <- f$COLL_NOM %>% unique %>% head(1)
  COLL_INSEE <- f$COLL_INSEE %>% get_first %>% format_code_insee
  titre_arrete <- glue("{COLL_NOM} ({COLL_INSEE})")
  titre_arrete
}

CSV2MD <- function(inputCSV, outputMD) {
  if(!file.exists(inputCSV)) {
    stop(inputCSV, " n'existe pas")
  }
  
  if(!dir.exists(dirname(outputMD))) {
    stop(dirname(outputMD), " n'existe pas")
  }
  
  message("Lecture de ", inputCSV)
  f <- read.csv(inputCSV, header = TRUE, sep = ",", encoding = "UTF-8")
  message("Rendu en cours...")
  res <- renderArreteAsMarkdown(f)
  message("Export vers ", outputMD)
  writeLines(res, outputMD)
}

CSV2HTML <- function(inputCSV, outputHTML) {
  if(!file.exists(inputCSV)) {
    stop(inputCSV, " n'existe pas")
  }
  
  if(!dir.exists(dirname(outputHTML))) {
    stop(dirname(outputHTML), " n'existe pas")
  }
  
  message("Lecture de ", inputCSV)
  f <- read.csv(inputCSV, header = TRUE, sep = ",", encoding = "UTF-8")
  message("Rendu en cours...")
  html <- f %>% renderArreteOfficial
  message("Export de ", outputHTML)
  writeLines(html, outputHTML)
}

arrete2List <- function(f) {
  # l <- arrete2List(f)
  
  l <- list()
  
  # ARRETE (ne traite qu'un arrêté pour le moment)
  l$titre_arrete    <- get_titre_arrete(f)
  l$arr_date        <- f$ARR_DATE %>% get_first
  l$arr_ref         <- f$ARR_REF %>% get_first
  l$arr_objet       <- f$ARR_OBJET %>% get_first
  l$arr_considerant <- f$ARR_CONSIDERANT %>% get_first %>% format_considerant
  
  # ARRETE > ARTICLES
  REGL_ARTICLES <- unique(f$REGL_ARTICLE)
  
  l$articles <- vector(mode = "list", length = length(REGL_ARTICLES))
  
  for (i in 1:length(REGL_ARTICLES)) {
    l$articles[[i]] <- REGL_ARTICLES[i]
    
    # ARRETE > SOUS_ARTICLES
    f1 <- f %>% filter(REGL_ARTICLE == REGL_ARTICLES[i])
    
    SOUS_ARTICLES <- unique(f1$REGL_SOUS_ARTICLE)
    
    l$articles[[i]]$sous_articles <- vector(mode = "list", length = length(SOUS_ARTICLES))
    
    for(j in 1:length(SOUS_ARTICLES)) {
      l$articles[[i]]$sous_articles[[j]] <- SOUS_ARTICLES[j]
      
      # ARTICLES > SOUS_ARTICLES > REGL_MOTIF
      f2 <- f1 %>% filter(REGL_SOUS_ARTICLE == SOUS_ARTICLES[j])
      
      MOTIFS <- unique(f2$REGL_MOTIF)
      
      l$articles[[i]]$sous_articles[[j]]$motifs <- vector(mode = "list", length = length(MOTIFS))
     
       for(k in 1:length(MOTIFS)) {
        l$articles[[i]]$sous_articles[[j]]$motifs[[k]] <- MOTIFS[k]
        
        # ARTICLES > VEHICULES
        f3 <- f2 %>% filter(REGL_MOTIF == MOTIFS[k]) %>% format_vehicule
        
        VEHICULES <- unique(f3$VEHICULE)
        
        l$articles[[i]]$sous_articles[[j]]$motifs[[k]]$vehicules <- vector(mode = "list", length = length(VEHICULES))
        
        for(m in 1:length(VEHICULES)) {
          l$articles[[i]]$sous_articles[[j]]$motifs[[k]]$vehicules[[m]] <- VEHICULES[m]
          
          # ARTICLES > VEHICULES > MODALITE
          f4 <- f3 %>% filter(VEHICULE == VEHICULES[m])
          
          REGL_MODALITES <- f4$REGL_MODALITE %>% unique
          
          l$articles[[i]]$sous_articles[[j]]$motifs[[k]]$vehicules[[m]]$modalites <- vector(mode = "list", length = length(REGL_MODALITES))
          
          for(n in 1:length(REGL_MODALITES)) {
            l$articles[[i]]$sous_articles[[j]]$motifs[[k]]$vehicules[[m]]$modalites[n] <- REGL_MODALITES[n]
            
            # ARTICLES > VEHICULES > MODALITE > PERIODE
            f5 <- f4 %>% filter(REGL_MODALITE == REGL_MODALITES[n]) %>% format_periode
            
            PERIODES <- unique(f5$PERIODE)
            
            l$articles[[i]]$sous_articles[[j]]$motifs[[k]]$vehicules[[m]]$modalites[[n]]$periodes <- vector(mode = "list", length = length(PERIODES))
            
            for(o in 1:length(PERIODES)) {
              l$articles[[i]]$sous_articles[[j]]$motifs[[k]]$vehicules[[m]]$modalites[[n]]$periodes[o] <- PERIODES[o]
              
              # ARTICLES > VEHICULES > MODALITE > PERIODE > EMPRISE
              f6 <- f5 %>% filter(PERIODE == PERIODES[o]) %>% format_emprise
              
              EMPRISES <- unique(f6$EMPRISE)
              l$articles[[i]]$sous_articles[[j]]$motifs[[k]]$vehicules[[m]]$modalites[[n]]$periodes[[o]]$emprises <- EMPRISES
            } # PERIODE
          } # MODALITE
        } # VEHICULE
      } # MOTIF
    } # SOUS_ARTICLE
  } # ARTICLE
  
  return(l)
}

renderArreteAsMarkdown <- function(f) {
  
  l <- arrete2List(f)
  
  md <- c()
  
  md <- c("# ", get_titre_arrete(f), "\n")
  md <- c(md, "**Date de l'arrêté :** ", l$arr_date, "\n\n")
  md <- c(md, "**Référence de l'arrêté :** ", l$arr_ref, "\n\n")
  md <- c(md, "**Objet de l'arrêté :** ", l$arr_objet, "\n\n")
  md <- c(md, "**Considérant :**\n\n", l$arr_considerant, "\n\n\n")
  
  for(article in l$articles) {
    md <- c(md, "# ", article[[1]], "\n")
    for(sous_article in article[[2]]) {
      md <- c(md, "## ", sous_article[[1]], "\n")
      for(motif in sous_article[[2]]) {
        if(display(motif[[1]])) {
          md <- c(md, "### Motif : ", motif[[1]], "\n")
        }
        for(vehicule in motif[[2]]) {
          md <- c(md, "#### ", vehicule[[1]], "\n")
          for(modalite in vehicule[[2]]) {
            md <- c(md, "##### ", modalite[[1]], "\n")
            for(periode in modalite[[2]]) {
              md <- c(md, "_Quand ?_\n\n")
              md <- c(md, "- ", periode[[1]], "\n\n")
              md <- c(md, "_Où ?_\n\n")
              for(emprise in periode[[2]]) {
                md <- c(md, "- ", emprise[[1]], "\n")
              }
              md <- c(md, "\n\n")
            }
          }
        }
      }
    }
  }
  
  res <- md %>% paste(collapse = "")
  return(res)
}

renderArreteOfficial <- function(f) {
  md <- renderArreteAsMarkdown(f)
  html <- knitr::knit2html(text = md, fragment.only = TRUE) %>% HTML
  html
}

OLD_arrete2md <- function(f) {
  
  # COLLECTIVITE
  # Sous la forme de metadata
  # De cette façon, le nom de l'arrêté apparaît dans l'en-tête
  titre_arrete <- get_titre_arrete(f)
  md <- c("# ", titre_arrete, c("\n\n"))
  
  # ARRETE
  ARR_DATE            <- f$ARR_DATE %>% get_first
  ARR_REF             <- f$ARR_REF %>% get_first
  ARR_OBJET           <- f$ARR_OBJET %>% get_first
  ARR_CONSIDERANT     <- f$ARR_CONSIDERANT %>% get_first %>% format_considerant
  
  if(display(ARR_DATE)) {
    md <- c(md, paste("Date de l'arrêté :", ARR_DATE %>% format_date,"  \n"))
  }
  if(display(ARR_REF)) {
    md <- c(md, paste("Référence de l'arrêté : ", ARR_REF,"  \n"))
  }
  if(display(ARR_OBJET)) {
    md <- c(md, paste("Objet de l'arrêté : ", ARR_OBJET,"  \n"))
  }
  if(display(ARR_CONSIDERANT)) {
    md <- c(md, "\n Considérant :\n\n", paste(ARR_CONSIDERANT,"  \n"))
  }
  
  md <- c("\n", md,"\n\n")
  
  # ARRETE > ARTICLES
  REGL_ARTICLES <- unique(f$REGL_ARTICLE)
  for (elt in REGL_ARTICLES) {
    md <- c(md, paste("# ", elt, "\n"))
    f1 <- f %>% filter(REGL_ARTICLE == elt)
    
    # ARRETE > SOUS_ARTICLES
    SOUS_ARTICLES <- unique(f1$REGL_SOUS_ARTICLE)
    for(elt in SOUS_ARTICLES) {
      md <- c(md, paste("## ", elt, "\n"))
      f2 <- f1 %>% filter(REGL_SOUS_ARTICLE == elt)
      
      # ARTICLES > SOUS_ARTICLES > REGL_MOTIF
      MOTIFS <- unique(f2$REGL_MOTIF)
      for(elt in MOTIFS) {
        if(display(elt)) {
          md <- c(md, paste("### Motif : ", elt, "\n"))
        }
        f3 <- f2 %>% filter(REGL_MOTIF == elt)
        
        # ARTICLES > VEHICULES
        f3 <- f3 %>% format_vehicule
        VEHICULES <- unique(f3$VEHICULE)
        for(elt in VEHICULES) {
          md <- c(md, paste("#### ", elt, "\n"))
          f4 <- f3 %>% filter(VEHICULE == elt)
          
          # ARTICLES > VEHICULES > MODALITE
          REGL_MODALITES <- f4$REGL_MODALITE %>% unique
          for(elt in REGL_MODALITES) {
            f5 <- f4 %>% filter(REGL_MODALITE == elt)
            modalite <- ifelse(elt == "Interdit", 
                               "##### Interdit", 
                               "##### Autorisé")
            md <- c(md, modalite, "\n")
            
            # ARTICLES > VEHICULES > MODALITE > PERIODE
            f5 <- f5 %>% format_periode
            PERIODES <- unique(f5$PERIODE)
            for(elt in PERIODES) {
              md <- c(md, "_Quand ?_", "\n\n")
              md <- c(md, "- ", elt, "\n\n")
              f6 <- f5 %>% filter(PERIODE == elt)
              
              # ARTICLES > VEHICULES > MODALITE > PERIODE > EMPRISE
              f6 <- f6 %>% format_emprise
              EMPRISES <- unique(f6$EMPRISE)
              md <- c(md, "_Où ?_", "\n\n")
              for(elt in EMPRISES) {
                md <- c(md, "- ", elt, "\n")
              } # EMPRISE
              md <- c(md, "\n\n")
            } # PERIODE
          } # MODALITE
          md <- c(md, "\n")
        } # VEHICULE
      } # MOTIF
    } # SOUS_ARTICLE
    md <- c(md, "\n")
  } # ARTICLE
  
  res <- md %>% paste(collapse = "")
  
  return(res)
}

format_tonnage <- function(VEH_TONNAGE_MIN = NA, VEH_TONNAGE_MAX = NA) {
  
  if(!is.na(VEH_TONNAGE_MIN) & is.na(VEH_TONNAGE_MAX)) {
    v <- glue(" de plus de {VEH_TONNAGE_MIN} tonnes")
  } else if(is.na(VEH_TONNAGE_MIN) & !is.na(VEH_TONNAGE_MAX)) {
    v <- glue(" de {VEH_TONNAGE_MAX} tonnes")
  } else if(!is.na(VEH_TONNAGE_MIN) & !is.na(VEH_TONNAGE_MAX)) {
    v <- glue(" entre {VEH_TONNAGE_MIN} et {VEH_TONNAGE_MAX} tonnes")
  } else if(is.na(VEH_TONNAGE_MIN) & is.na(VEH_TONNAGE_MAX)) {
    v <- ""
  }
  return(v)
}

format_vehicule <- function(f) {
  
  VEH_TONNAGE <- sapply(1:nrow(f), function(x) format_tonnage(f$VEH_TONNAGE_MIN[x], 
                                                              f$VEH_TONNAGE_MAX[x]))
  
  f %>% mutate(VEHICULE = sprintf("%s%s%s%s%s%s%s", 
                                  VEH_TYPES, 
                                  VEH_TONNAGE,
                                  ifelse(
                                    display(VEH_LONG), 
                                    sprintf(", de %s m de long", gsub("\\|", ", ", VEH_LONG)), 
                                    ""),
                                  ifelse(
                                    display(VEH_LARG), 
                                    sprintf(", de %s m de large", gsub("\\|", ", ", VEH_LARG)), 
                                    ""),
                                  ifelse(
                                    display(VEH_HAUT), 
                                    sprintf(", de %s m de haut", gsub("\\|", ", ", VEH_HAUT)), 
                                    ""),
                                  ifelse(
                                    display(VEH_USAGES), 
                                    sprintf(" (%s)", gsub("\\|", ", ", VEH_USAGES)), 
                                    ""), 
                                  ifelse(
                                    display(VEH_MOTORS), 
                                    sprintf(", Motorisation :",
                                            gsub("\\|", ", ", VEH_MOTORS)), ""),
                                  ifelse(
                                    display(VEH_CQAS), 
                                    sprintf(", Etiquette CQA :",
                                            gsub("\\|", ", ", VEH_CQAS)), "")))
}

format_periode <- function(f) {
  
  jours_horaires <- sapply(f$PERIODE_JH, explain_oh)
  
  f <- f %>% mutate(PERIODE = sprintf("%s%s%s",
                                 ifelse(display(PERIODE_JH), sprintf("%s", jours_horaires), ""),
                                 ifelse(display(PERIODE_DEBUT), sprintf(" depuis %s", PERIODE_DEBUT), ""),
                                 ifelse(display(PERIODE_FIN), sprintf(" jusqu'à %s", PERIODE_FIN), "")
  ))
  
  f$PERIODE <- ifelse(f$PERIODE == "", "Tous les jours (non renseigné)", f$PERIODE)
    
  return(f)
}

format_emprise <- function(f) {
  
  f %>% mutate(EMPRISE = sprintf("%s%s%s%s", 
                                 EMPRISE_DESIGNATION,
                                 ifelse(display(EMPRISE_SENS), sprintf(" (%s)", EMPRISE_SENS), ""), 
                                 ifelse(display(EMPRISE_DEBUT), sprintf(" de %s", EMPRISE_DEBUT), ""), 
                                 ifelse(display(EMPRISE_FIN), sprintf(" à %s", EMPRISE_FIN), "")
  ))
}

format_considerant <- function(ARR_CONSIDERANT) {
  if(grepl("Considérant|considérant", ARR_CONSIDERANT)) {
    
    ARR_CONSIDERANT <- gsub("^Considérant ", "", ARR_CONSIDERANT)
    ARR_CONSIDERANT <- gsub("^considérant ", "", ARR_CONSIDERANT)
    
    l <- lapply(strsplit(ARR_CONSIDERANT, ", Considérant"), 
                function(x) strsplit(x, ",Considérant"))
    
    s <- unlist(l, recursive = T) %>% sapply(function(x) glue("- {x}")) %>% paste(collapse = "\n")
    return(s)
  } else {
    ARR_CONSIDERANT
  }
}