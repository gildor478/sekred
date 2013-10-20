
default: test

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

# Deploy target
#  Deploy/release the software.

OASIS2DEBIAN_ARGS="--distribution wheezy \
		--executable-name sekred \
		--group sekred,/var/lib/sekred \
		--dh-dirs sekred,var/lib/sekred/domains \
		--dpkg-statoverride /usr/bin/sekred,root,sekred,2755 \
		--dpkg-statoverride /var/lib/sekred/domains,root,sekred,1770"

deploy: headache
	admin-gallu-deploy --verbose \
		--debian_pkg --debuild --debian_upload \
		--oasis2debian_args '$(OASIS2DEBIAN_ARGS)' \
		--forge_upload	--forge_group sekred --forge_user gildor-admin
	admin-gallu-oasis-increment --use_vcs \
		--setup_run --setup_args '-setup-update dynamic'

.PHONY: deploy

# Precommit target
#  Check style of code.
PRECOMMIT_ARGS= \
	    --exclude myocamlbuild.ml \
	    --exclude setup.ml \
	    --exclude README.txt \
	    --exclude INSTALL.txt \
	    --exclude Makefile \
	    --exclude configure \
	    --exclude _tags

precommit:
	@if command -v OCamlPrecommit > /dev/null; then \
	  OCamlPrecommit $(PRECOMMIT_ARGS); \
	else \
	  echo "Skipping precommit checks.";\
	fi

precommit-full:
	OCamlPrecommit --full $(PRECOMMIT_ARGS)

test: precommit

.PHONY: precommit

# Fix perms target
#  Fix missing permission for darcs VCS files.
fix-perms:
	# TODO: chmod +x doc-dist.sh

.PHONY: fix-perms

# Headache target
#  Fix license header of file.

headache:
	find ./ \
	  -name _darcs -prune -false \
	  -name .git -prune -false \
	  -name .svn -prune -false \
	  -o -name _build -prune -false \
	  -o -name dist -prune -false \
	  -o -name '*[^~]' -type f \
	  | xargs headache -h _header -c _headache.config

.PHONY: headache
