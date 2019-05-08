# [rtofs](https://polar.ncep.noaa.gov/global/nc/) Global Real Time Ocean Forecast System

Provides simplified access to OPeNDAP [Real-time Ocean Forecast System](https://polar.ncep.noaa.gov/global/nc/) 
(rtofs) data served by the NOMADS OPeNDAP server](https://nomads.ncep.noaa.gov:9090/dods/rtofs).

## Requirements

+ [R version 3+](https://www.r-project.org/)

+ [sp](https://CRAN.R-project.org/package=sp) 
    
+ [ncdf4](https://CRAN.R-project.org/package=ncdf4)
    
+ [raster](https://CRAN.R-project.org/package=raster)

## Installation

Using [devtools](https://CRAN.R-project.org/package=devtools)

```
devtools::install_github("BigelowLab/rtofs")
```

## Usage

Here's an example the accesses yesterday's surface current forecasts and draws
then using [rasterVis](https://CRAN.R-project.org/package=rasterVis).

```
library(rtofs)
library(raster)
library(rasterVis)
uri = daily_glo2ds_uri()
NC = rtofs_daily_glo2ds(uri)
U  = rtofs_glo2ds_get_raster(NC, bb = c(-72, -63, 39, 46), param = 'u_velocity')
V  = rtofs_glo2ds_get_raster(NC, bb = c(-72, -63, 39, 46), param = 'v_velocity')

day3 = raster::stack(U[[3]], V[[3]])
names(day3) <- c("U", "V")
day5 = raster::stack(U[[5]], V[[5]])
names(day5) <- c("U", "V")

p3 <- vectorplot(day3, par.settings=PuOrTheme(), isField = 'dXY', margin=FALSE, main = 'Day 3 currents')
p5 <- vectorplot(day5, par.settings=PuOrTheme(), isField = 'dXY', margin=FALSE, main = 'Day 5 currents')
  
print(p3, split=c(1, 1, 1, 2), more=TRUE)
print(p5, split=c(1, 2, 1, 2))
```

![image](https://github.com/BigelowLab/rtofs/blob/master/inst/currents-day3-day5.png)
