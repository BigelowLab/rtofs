library(raster)
library(rasterVis)
library(ncdf4)
library(sp)
library(latticeExtra)

COAST <- celmap::get_vectors(where = 'GOM', what = 'coast50m')

source('/mnt/ecocast/corecode/R/rtofs/R/glo_2ds.R')
uri = daily_glo2ds_uri()
NC = rtofs_daily_glo2ds(uri)
U  = rtofs_glo2ds_get_raster(NC, bb = c(-72, -63, 39, 46), param = 'u_velocity')
V  = rtofs_glo2ds_get_raster(NC, bb = c(-72, -63, 39, 46), param = 'v_velocity')

u = U[[1]]
v = V[[1]]

u3 = raster::focal(u, matrix(1,3,3), fun = mean, na.rm = TRUE)
v3 = raster::focal(v, matrix(1,3,3), fun = mean, na.rm = TRUE)
u5 = raster::focal(u, matrix(1,5,5), fun = mean, na.rm = TRUE)
v5 = raster::focal(v, matrix(1,5,5), fun = mean, na.rm = TRUE)
u7 = raster::focal(u, matrix(1,7,7), fun = mean, na.rm = TRUE)
v7 = raster::focal(v, matrix(1,7,7), fun = mean, na.rm = TRUE)
S = stack(u,u3, u5, u7, v, v3, v5, v7 )
names(S) <- c("u", "u3", "u5", "u7", "v", "v3", "v5", "v7")
vectorplot(S, par.settings=PuOrTheme(), isField = 'dXY')  + latticeExtra::layer(sp.polygons(COAST))
