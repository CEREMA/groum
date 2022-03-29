options(warn = -1)

suppressMessages(library(optparse, quietly = T))
suppressMessages(library(tidyverse, quietly = T))
suppressMessages(library(sf, quietly = T))
suppressMessages(library(geojsonsf, quietly = T))
suppressMessages(library(stringdist, quietly = T))
suppressMessages(library(glue, quietly = T))
suppressMessages(library(jsonlite, quietly = T))
suppressMessages(library(stringi, quietly = T))
suppressMessages(library(lubridate, quietly = T))
suppressMessages(library(shiny, quietly = T))
# library(lubridate)
# library(shiny)

source("functions/functions.R", encoding = "UTF-8")
source("functions/imports/main.R", encoding = "UTF-8")
source("functions/imports/geocode.R", encoding = "UTF-8")
source("functions/imports/markdown.R", encoding = "UTF-8")
source("functions/imports/opening-hours.R", encoding = "UTF-8")

# Config ----
parser <- OptionParser()
parser <- add_option(parser, c("-i", "--input"), 
                     dest="input",
                     help="Input CSV file", 
                     metavar="CSV")

parser <- add_option(parser, c("-o", "--output"), 
                     dest="output",
                     help="Output file : can be (Geo)CSV, HTML, GPKG, MD (Markdown file)", 
                     metavar="")

parser <- add_option(parser, c("-s", "--streets"), 
                     dest="streets",
                     help="Spatial file containing the streets (only for geocoding process)", 
                     metavar="Spatial")

parser <- add_option(parser, c("-g", "--geom"), 
                     dest="geomcol",
                     help="Geometry column in the CSV file (for the conversion to GPKG)", 
                     metavar="GeomCol")

# Arguments ----
args <- commandArgs(trailing = TRUE)

# Process ----
groum <- function(args) {

  args      <- parse_args(parser, args = args)
  extension <- gsub("^.*\\.(.*)$", "\\1", args$output)
  
  if(length(extension) == 0) {
    # "Chemain du Plan d'Ollive,Charles de Gaulle"
    geocode_street(street      = args$input,
                   streetsFile = args$streets)
  } else if(extension == "csv") {

    geocode_CSV(inputCSV = args$input,
               streets   = args$streets,
               output    = args$output)

  } else if(extension == "md") {

    CSV2MD(inputCSV = args$input,
           outputMD = args$output)

  } else if(extension == "html") {

    CSV2HTML(inputCSV   = args$input,
             outputHTML = args$output)

  } else if(extension == "gpkg") {

    CSV2GPKG(inputCSV   = args$input,
             outputGPKG = args$output,
             geomCol    = args$geomcol)
    
  } else if(extension == "jpeg") {
    
    CSV2JPEG(inputCSV   = args$input,
             outputJPEG = args$output,
             geomCol    = args$geomcol)
  }
}

groum(args)