
# OASIS_START
# DO NOT EDIT (digest: bc1e05bfc8b39b664f29dae8dbd3ebbb)

SETUP = ocaml setup.ml

build: setup.data
	$(SETUP) -build $(BUILDFLAGS)

doc: setup.data build
	$(SETUP) -doc $(DOCFLAGS)

test: setup.data build
	$(SETUP) -test $(TESTFLAGS)

all: 
	$(SETUP) -all $(ALLFLAGS)

install: setup.data
	$(SETUP) -install $(INSTALLFLAGS)

uninstall: setup.data
	$(SETUP) -uninstall $(UNINSTALLFLAGS)

reinstall: setup.data
	$(SETUP) -reinstall $(REINSTALLFLAGS)

clean: 
	$(SETUP) -clean $(CLEANFLAGS)

distclean: 
	$(SETUP) -distclean $(DISTCLEANFLAGS)

setup.data:
	$(SETUP) -configure $(CONFIGUREFLAGS)

.PHONY: build doc test all install uninstall reinstall clean distclean configure

# OASIS_STOP

OASIS2DEBIAN_ARGS="--distribution squeeze \
		--executable-name sekred \
		--group sekred,/var/lib/sekred \
		--dh-dirs sekred,var/lib/sekred/domains \
		--dpkg-statoverride /usr/bin/sekred,root,sekred,2755 \
		--dpkg-statoverride /var/lib/sekred/domains,root,sekred,1730"

deploy:
	../admin-gallu/src/admin-gallu-deploy --verbose \
		--debian_pkg --debuild --debian_upload \
		--oasis2debian_args '$(OASIS2DEBIAN_ARGS)'
