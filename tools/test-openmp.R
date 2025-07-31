args <- commandArgs(TRUE)
setwd(tempdir())

# Make macros could also be expanded from environment variables, but
# this is simpler
writeLines(c(
	paste("PKG_CFLAGS =", args[[1]]),
	paste("PKG_LIBS =", args[[2]])
), "Makevars")

writeLines("
#ifdef _OPENMP
 #include <omp.h>
#endif
void test_openmp(int * result) {
 int sum = 0;
#ifdef _OPENMP
 /* Sometimes compile-, link-, and load-tests are not enough.
 ** So actually try to run an OpenMP loop. */
 #pragma omp parallel for reduction(+:sum) num_threads(2)
 for (int i = 1; i <= 2; ++i) sum += i;
#endif
 *result = sum;
}
", "test.c")

# should return 3 if OpenMP works or 0 if it doesn't
desired <- 3L
not_working <- 0L

stopifnot("Failed to compile." = tools::Rcmd("SHLIB --preclean test.c") == 0)

dll <- paste0("test", .Platform$dynlib.ext)
dyn.load(dll)
ans <- .C("test_openmp", ans = integer(1))$ans
dyn.unload(dll)

cat(sprintf(
	"Return value is %d (%d indicates success, %d indicates OpenMP disabled)\n",
	ans, desired, not_working
))
stopifnot(identical(ans, desired))
