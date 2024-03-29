library(tidyverse)
library(tidycensus)
library(sf)
library(fasterize)
library(raster)
library(reshape)
library(tigris)


#census_api_key(key = "a16f3636406d2b544871e2ae49bb318c3ddcacba",
#               overwrite = TRUE,
#               install = TRUE) # get an API key from api.census.gov/data/key_signup.html
Sys.getenv("CENSUS_API_KEY")
# v17 <- load_variables(2010, "sf1", cache = TRUE)
# View(v17)

pghPopulation <- get_decennial(geography = 'block', # also try tract
                               variables = 'H010001', geometry = T, 
                               state = 'PA', county = 'Allegheny', year = 2010)

# # Run code below for metro area
# camdenPopulation <- get_decennial(geography = 'block',
#                                   variables = 'H010001', geometry = T,
#                                   state = 'NJ', county = 'Camden', year = 2010)

# population density
pghPopulation$density <- pghPopulation$value/st_area(pghPopulation)

# reproject sf object
pghPopulation <- st_transform(pghPopulation, "+proj=lcc +lat_1=39.93333333333333 +lat_2=40.96666666666667 +lat_0=39.33333333333334 +lon_0=-77.75 +x_0=600000 +y_0=0 +datum=NAD83 +units=us-ft +no_defs")

# create empty raster and rasterize sf polygons
r <- raster(ncol = 100, nrow = 100)
extent(r) <- extent(pghPopulation)
popDensRaster <- fasterize(pghPopulation, r, field = 'density', fun = 'last')
# plot(popDensRaster)


coords <- as.data.frame(coordinates(popDensRaster))
values <- data.frame(pop = values(popDensRaster),
                     x = coords$x,
                     y = coords$y)


# standardize values for easier visualization
range01 <- function(x){(x-min(x))/(max(x)-min(x))}
values$pop[is.na(values$pop)] <- 0
values$pop_st <- range01(values$pop)*0.10 # this scalar will affect how peaky the peaks are. Higher value = peakier
values$pop_st[values$pop > 0.0828908] <- 0 # make maximum 0...a weird block NW of fairmount park
values$x_st <- range01(values$x)
values$y_st <- range01(values$y)



xquiet <- scale_x_continuous("", breaks=NULL)
yquiet <- scale_y_continuous("", breaks=NULL)
quiet <- list(xquiet, yquiet)

values$ord <- values$y
values_s <- values[order(-values$ord),]


# Create an empty plot called p
p <- ggplot()

backgroundColor <- 'black' # other colors I like: blue #1D3A7D, gray #B2B6BF, coral #F88379
lineColor <- 'gold'

# This loops through each line of latitude and produced a filled polygon that will mask out the 
# lines beneath and then plots the paths on top.The p object becomes a big ggplot2 plot.
for (i in unique(values_s$ord)){
  p <- p + geom_polygon(data = values_s[values_s$ord == i,], aes(x_st, pop_st + y_st, group = y_st), 
                        size = 0.2, fill = backgroundColor, col = backgroundColor) + 
    geom_path(data = values_s[values_s$ord == i,],aes(x_st, pop_st + y_st, group = y_st), size = 0.2, 
              lineend = 'round', col = lineColor)
}


# Display plot and save as pdf
plot <- p + theme(panel.background = element_rect(fill = backgroundColor,colour = backgroundColor)) + quiet

plot

ggsave(plot, "output/population_lines.png", device = "png")
# dev.off()