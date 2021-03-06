% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/clusters.R
\name{clusterKmeans}
\alias{clusterKmeans}
\title{K-Means Clustering Automated}
\usage{
clusterKmeans(df, k = NA, limit = 20, drop_na = TRUE, ohse = TRUE,
  norm = TRUE, comb = c(1, 2), seed = 123)
}
\arguments{
\item{df}{Dataframe}

\item{k}{Integer. Number of clusters}

\item{limit}{Integer. How many clusters should be considered?}

\item{drop_na}{Boolean. Should NA rows be removed?}

\item{ohse}{Boolean. Do you wish to automatically run one hot
encoding to non-numerical columns?}

\item{norm}{Boolean. Should the data be normalized?}

\item{comb}{Vector. Which columns do you wish to plot? Select which
two variables by name or column position.}

\item{seed}{Numeric. Seed for reproducibility}
}
\description{
This function lets the user cluster a whole data.frame automatically.
If needed, one hot encoding will be applied to categorical values.
}
