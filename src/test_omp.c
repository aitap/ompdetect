#ifdef _OPENMP
	#include <omp.h>
#endif

#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

static SEXP limits(void) {
	SEXP ret = allocVector(INTSXP, 3);
	int * pret = INTEGER(ret);
#ifdef _OPENMP
	pret[0] = omp_get_thread_limit();
	pret[1] = omp_get_max_threads();
	pret[2] = omp_get_num_procs();
#else
	pret[0] = pret[1] = pret[2] = -1;
#endif
	return ret;
}

static SEXP test_omp(void) {
	SEXP ret = allocVector(LGLSXP, 1);
	*LOGICAL(ret) =
	#ifdef _OPENMP
		1
	#else
		0
	#endif
	;
	return ret;
}

static R_CallMethodDef call_methods[] = {
	{"limits", (DL_FUNC)&limits, 0},
	{"test_omp", (DL_FUNC)&test_omp, 0},
	{NULL, NULL, 0}
};

void R_init_ompdetect(DllInfo *info) {
	R_registerRoutines(info, NULL, call_methods, NULL, NULL);
	R_useDynamicSymbols(info, FALSE);
	R_forceSymbols(info, TRUE);
}
