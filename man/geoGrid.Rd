% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/geodata.R
\name{geoGrid}
\alias{geoGrid}
\title{Check, Cross, and Plot Coordinates with Polygons}
\usage{
geoGrid(coords, shapes, transform = FALSE, plot = FALSE, all = FALSE)
}
\arguments{
\item{coords}{Dataframe. Dataframe containing at least langitud 
and latitud data}

\item{shapes}{SpatialPolygonsDataFrame.}

\item{transform}{Boolean. Transform and fix coordinates system?}

\item{plot}{Boolean. Return plot with coordinates inside the grid?}

\item{all}{Boolean. Include all coordinates in plot, i.e. only the 
ones who are inside the grids?}
}
\description{
This function checks a series of coordinates and return a join
with the information of each coordinate and its respective grid.
Note that the coords and shapes coordinates MUST have the same 
lon/lat reference system for it to work succesfully.
}
