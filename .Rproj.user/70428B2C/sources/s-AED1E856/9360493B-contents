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

source("helpers/main.R")
source("helpers/imports/main.R")
source("helpers/imports/geocode.R")
source("helpers/imports/markdown.R")
source("helpers/imports/opening-hours.R")

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
                     dest="geom",
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
    geocodeStreet(street      = args$input,
                  streetsFile = args$streets)
  } else if(extension == "csv") {

    geocodeCSV(input   = args$input,
               streets = args$streets,
               output  = args$output)

  } else if(extension == "md") {

    CSV2MD(input  = args$input,
           output = args$output)

  } else if(extension == "html") {

    CSV2HTML(input = args$input,
             output = args$output)

  } else if(extension == "gpkg") {

    CSV2GPKG(input    = args$input,
             output   = args$output,
             geom = "X_GEOM_WKT")

  }
}

groum(args)