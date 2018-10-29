#LOCAL AUTHORITY AND NEWSROOM GENERATOR
#This takes badly formatted location data and finds Local Authority Name
#and also attaches a column with relevant Reach PLC newsroom.
#Last Updated: 29/10/18 Version: 1.0 By: Michael Goodier

# Setup -------------------------------------------------------------------

#Libraries
library(ggmap)
library(sp)
library(sf)
library(maptools)
library(readr)
library(dplyr)
library(rgdal)
library(spdplyr)

# Add Google Geocode API key (may want to register your own so I don't run out of free credit)
register_google(key = "YOUR GOOGLE KEY", account_type = "premium")

#load csv with locations you want coded (change "folder" to the folder you are working from which contains shapefiles + csv)
setwd("folder")
dataframe <- read_csv("dataframe.csv") #change "dataframe.csv" to your csv containg locations

#cleaning
names(dataframe)[names(dataframe) == 'old name'] <- 'locations' # Used to rename column of choice ("old name") to "locations"
#dataframe[] <- lapply(dataframe, gsub, pattern='[^ -~]', replacement='') # Used to strip out non-utf characters (if needed)

#load LA to newsroom lookup
newsrooms <- read_csv("newsrooms.csv")

# Geocoding ----------------------------------------------------------------

#dataframe is your dataframe, locations is the name of the column with your locations in
#you can only geocode up to 2500 in one go afaik
#this uses google to create lat/lon columns from your badly formatted location data

#adds ", UK" to the end of each location to avoid confusion with other countries
dataframe$locationsuk <- paste0(dataframe$locations, ", UK")

#geocode
#TO DO: Group by location then join later in order to avoid repeat requests
geocoded <- geocode(dataframe$locationsuk, output = "latlona", source = "google")

#merge our results with initial dataframe
geocoded <- bind_cols(dataframe, geocoded)

# Load shapefile of Local Authority Districts ------------------------------

#Shapefile downloaded from here: http://geoportal.statistics.gov.uk/datasets/local-authority-districts-december-2017-full-clipped-boundaries-in-great-britain
#TO DO: Add in Northern Ireland

#read UK LA Shapefile (from current working directory)
uk.shp <- readOGR(dsn = ".", layer = "Local_Authority_Districts_December_2017_Full_Clipped_Boundaries_in_Great_Britain")
 
# Convert to longitude / latitude with WGS84 Coordinate System
wgs84 = '+proj=longlat +datum=WGS84'
uk.shp_trans <- spTransform(uk.shp, CRS(wgs84))

#create spatial points dataframe of our locations

locations.sp <- geocoded %>% select(lon,lat)
coordinates(locations.sp) <- ~lon+lat
proj4string(locations.sp) <- CRS(wgs84) #sets co-ordinate system

# Find LA and merge --------------------------------------------------------

#take LA data from uk shapefile and attach to points within LA
extracted.data <- over(locations.sp, uk.shp_trans)

#merge our results with initial dataframe
geocoded$LA <- extracted.data$lad17nm

#add newsroom to dataframe
geocoded <- left_join(geocoded, newsrooms, by = "LA")

#export csv file 
write_csv(geocoded, "geocoded.csv")
