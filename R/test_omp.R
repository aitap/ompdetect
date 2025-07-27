ompdetect <- function() {
	ret <- .Call(test_omp)
	message(if (ret) "OpenMP detected and working." else "OpenMP not detected.")
	invisible(ret)
}

omplimits <- function() {
	setNames(.Call(limits), c('thread_limit', 'max_threads', 'num_procs'))
}
