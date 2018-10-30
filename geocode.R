#LOCAL AUTHORITY AND NEWSROOM GENERATOR
#This takes badly formatted location data and finds Local Authority Name
#and also attaches a column with relevant Reach PLC newsroom.
#put in folder with newsrooms.csv and the shapefiles
#Last Updated: 29/10/18 Version: 1.0 By: Michael Goodier

# 0 Setup -------------------------------------------------------------------

#Libraries
library(ggmap)
library(sp)
library(sf)
library(maptools)
library(readr)
library(dplyr)
library(rgdal)
library(spdplyr)
library(tidyr)

# Add Google Geocode API key (may want to register your own https://developers.google.com/maps/documentation/geocoding/get-api-key)
register_google(key = "YOUR_API_KEY", account_type = "premium")

#load csv with locations you want coded (change "folder" to the folder you are working from which contains shapefiles + csv)
setwd("YOUR FOLDER")
dataframe <- read_csv("YOUR CSV.csv") #change "YOUR CSV.csv" to your csv containg location data

#cleaning
names(dataframe)[names(dataframe) == 'OLD COLUMN NAME'] <- 'locations' # Used to rename column of choice ("old name") to "locations"
#dataframe[] <- lapply(dataframe, gsub, pattern='[^ -~]', replacement='') # Used to strip out non-utf characters (if needed)

#load LA to newsroom lookup
newsrooms <- read_csv("newsrooms.csv")

# 1 Geocoding ----------------------------------------------------------------
#if you already have lat/lon, skip to step 2

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

# 2 Load shapefile of Local Authority Districts ------------------------------

#skipping straight here as already have lat/lon columns? do:
#geocoded <- dataframe
#geocoded <- drop_na(geocoded, lon) #remove any NAs from lat/lon

#Shapefile downloaded from here: http://geoportal.statistics.gov.uk/datasets/local-authority-districts-december-2017-full-clipped-boundaries-in-great-britain
#TO DO: Add in Northern Ireland

#read UK LA Shapefile (from current working directory) - takes a bit of time as large
uk.shp <- readOGR(dsn = ".", layer = "Local_Authority_Districts_December_2017_Full_Clipped_Boundaries_in_Great_Britain")
 
# Convert to longitude / latitude with WGS84 Coordinate System - again takes a bit of time
wgs84 = '+proj=longlat +datum=WGS84'
uk.shp_trans <- spTransform(uk.shp, CRS(wgs84))

#create spatial points dataframe of our locations

locations.sp <- geocoded %>% select(lon,lat)
coordinates(locations.sp) <- ~lon+lat
proj4string(locations.sp) <- CRS(wgs84) #sets co-ordinate system

# 3 Find LA and merge --------------------------------------------------------

#take LA data from uk shapefile and attach to points within LA (takes a bit of time)
extracted.data <- over(locations.sp, uk.shp_trans)

#merge our results with initial dataframe
geocoded$LA <- extracted.data$lad17nm

#add newsroom to dataframe
geocoded <- left_join(geocoded, newsrooms, by = "LA")

#export you new csv file 
write_csv(geocoded, "geocoded.csv")
