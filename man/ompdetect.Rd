\name{ompdetect}
\alias{ompdetect}
\alias{omplimits}
\title{Did we detect OpenMP on this system?}
\description{
  Print and return whether OpenMP support was detected during
  configuration of this package. Additionally, show the various limits
  on the number of OpenMP threads.
}
\usage{
  ompdetect()
  omplimits()
}
\details{
  All the work is done during the package configuration.
}
\value{
  Invisible \code{TRUE} if OpenMP was detected during configuration,
  \code{FALSE} otherwise. Also emits a \code{\link[base]{message}} with
  the result of the check.
}
\references{
  \dQuote{Writing R Extensions}, section 1.2.1.1, OpenMP support:
  \url{https://cran.r-project.org/doc/manuals/R-exts.html#OpenMP-support}.
}
\examples{
  ompdetect()
  omplimits()
}
