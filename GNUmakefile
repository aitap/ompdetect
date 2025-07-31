R = R
PACKAGE_NAME = $(shell $(R)script -e "\
 cat(read.dcf('DESCRIPTION')[,'Package'])\
")
PACKAGE = $(shell $(R)script -e "\
 cat(read.dcf('DESCRIPTION')[,c('Package','Version')], sep = '_'); \
 cat('.tar.gz') \
")
all: $(PACKAGE)

.PHONY: all check check-cran install-local

$(PACKAGE): .Rbuildignore cleanup configure DESCRIPTION man/* NAMESPACE R/* README.md src/*
	$(R) CMD build .

check: $(PACKAGE)
	$(R) CMD check $(PACKAGE)

check-cran: $(PACKAGE)
	$(R) CMD check --timings --as-cran $(PACKAGE)

install-local: $(PACKAGE)
	mkdir -p $(PACKAGE_NAME).Rcheck
	$(R) CMD INSTALL -l $(PACKAGE_NAME).Rcheck $(PACKAGE)
