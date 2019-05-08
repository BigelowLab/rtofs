#' Retrieve the daily GLobal RTOFS glo2ds uri for the specifed date.  There is no test to
#' determine if the uri points to a valid resource.
#'
#' @export
#' @param date character, Date or POSIXt, the date to retrieve, by default yesterday as Date class.
#'             if provided as character it must be in YYYYmmdd format (no separator)
#' @param when character, either 'forecast' or 'nowcast'
#' @param what character, either 'prog' (prognosis) or 'diag' (diagnosis)
#' @param root character, the root uri
#' @return ncdf4 class object or NULL
daily_glo2ds_uri <- function(date = Sys.Date() - 1,
                             when = c("forecast", "nowcast")[1],
                             what = c("prog", "diag")[1],
                             root = "https://nomads.ncep.noaa.gov:9090/dods/rtofs"){

    if (inherits(date, "Date") | inherits(date, "POSIXt")) date <- format(date, "%Y%m%d")
    base <- sprintf("rtofs_global%s/rtofs_glo_2ds_%s_daily_%s", date[1], tolower(when[1]), tolower(what[1]))
    file.path(root, base)
}


#' Open a connection to an OPeNDAP resource
#'
#' @export
#' @param uri character, uri for an opendap resource
#' @return ncdf4 object or NULL
rtofs_daily_glo2ds <- function(uri = daily_glo2ds_uri()){
    tryCatch(
        expr = {ncdf4::nc_open(uri)},
        error = function(e){
            message("Unable to connect to ", uri)
            print(e)
            NULL
        })
}


#' Retrieve a vector of date times for the layers in a NCDF4 object
#'
#' @export
#' @param NC ncdf4 class object
#' @return a vector of Dates, POSIXct (one for each layer) or NULL
rtofs_time <- function(NC){

    dt <- NULL
    if ("time" %in% names(NC$dim)){
         s <- strsplit(NC$dim$time$units, " ", fixed = TRUE)[[1]]
         dt0 <- paste(s[c(length(s)-1, length(s))], collapse = " ")
         units <- s[1]
         start <- switch(units,
                         'days' = as.Date(dt0),
                         as.POSIXct(dt0, format = "%Y-%m-%d %H:%M:%S", tz = 'UTC')
                         )
         dt <- start +  NC$dim$time$vals
    }
    dt
}

#' Compute the elements for navigating ncfd4 array extraction
#'
#' @export
#' @param NC ncdf4 class object
#' @param bb numeric, a 4 element vector specifing the bonding box in
#'           [left, right, bottom, top] order.
#' @param level numeric vector or one or more contiguous level numbers.  Since
#'              we are accessing surface data this is a bit of a red herring.  Best
#'              to accept the default.
#' @param layers numeric vector or one or more contiguous layer numbers.
#' @param offset numeric the longitudinal offset need to translate between the
#'               typical [-180, 180] to the rtofs degrees east system. By default it
#'               is 360 which implies the input bb longitudes range form [-180, 180].
#'               If the actual bb longitudes are [0,360] then set this to min(NC$dim$lon$vals)
#' @return a list of navigation elements
#' \itemize{
#' \item{start a three element vector of start indices}
#' \item{count a three elemen count of the indices after start}
#' \item{lon a vector of the offset-translated longitude coordinates for the subset}
#' \item{lat a vector of the latitude coordinates for the subset}
#' \item{time a vector of POSIXct datetime vakues for each layer}
#' \item{res a two element of x and y resolution in rtofs native coordinates}
#' }
rtofs_glo2ds_nav <- function(NC,
                             bb = c(-72, -63, 39, 46),
                             level = 1,
                             layers = seq_len(NC$dim$time$len),
                             offset = 360){

    lon <- as.vector(NC$dim$lon$vals)
    lat <- as.vector(NC$dim$lat$vals)

    closest <- function(x, v){
        which.min(abs(v-x))
    }

    ix <- sapply(bb[1:2] + offset, closest, v = lon)
    iy <- sapply(bb[3:4], closest, v = lat)

    list(
        start = c(ix[1], iy[1], level[1], layers[1]),
        count = c(ix[2]-ix[1] + 1, iy[2] - iy[1] + 1, length(level), length(layers)),
        lon   = lon[ix[1]:ix[2]] - offset,
        lat   = lat[iy[1]:iy[2]],
        res   = abs(c(lon[2]-lon[1], lat[2]-lat[1])),
        dt    = rtofs_time(NC)[layers]
    )
}


#' Retrieve a Raster* for a user specified bounding box
#'
#' @export
#' @param NC ncdf4 class object
#' @param param character the name of the parameter to extract
#' @param ... further arguments for \code{\link{rtofs_glo2ds_nav}}
#' @return raster of one or more layers or NULL
rtofs_glo2ds_get_raster <- function(NC = rtofs_daily_glo2ds(),
                                    param = 'sst',
                                    ...){
    R <- NULL
    nav <- rtofs_glo2ds_nav(NC, ...)
    x  <- ncdf4::ncvar_get(NC, param, start = nav$start, count = nav$count)
    half <- nav$res/2
    template <- raster::raster(
                       resolution = nav$res,
                       xmn = min(nav$lon) - half[1],
                       xmx = max(nav$lon) + half[1],
                       ymn = min(nav$lat) - half[2],
                       ymx = max(nav$lat) + half[2],
                       crs = "+proj=longlat +datum=WGS84 +ellps=WGS84 +towgs84=0,0,0")
    d <- dim(x)
    if (length(d) == 2) {
        x <- t(x)
        R <- raster::raster(x, template = template)
    } else {
        x <- aperm(x, c(2,1,3))
        RR <- lapply(seq_len(d[3]),
                     function(i){
                         raster::raster(x[,,i], template = template)
                     })
        R <- raster::stack(RR)
    }

    if (!is.null(R)) {
        R <- raster::flip(R, "y")
        names(R) <- format(nav$dt, format = "A%Y%j")
    }
    R
}
