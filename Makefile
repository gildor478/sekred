################################################################################
#  sekred: Password manager for automatic installation.                        #
#                                                                              #
#  Copyright (C) 2013, Sylvain Le Gall                                         #
#                                                                              #
#  This library is free software; you can redistribute it and/or modify it     #
#  under the terms of the GNU Lesser General Public License as published by    #
#  the Free Software Foundation; either version 2.1 of the License, or (at     #
#  your option) any later version, with the OCaml static compilation           #
#  exception.                                                                  #
#                                                                              #
#  This library is distributed in the hope that it will be useful, but         #
#  WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY  #
#  or FITNESS FOR A PARTICULAR PURPOSE. See the file COPYING for more          #
#  details.                                                                    #
#                                                                              #
#  You should have received a copy of the GNU Lesser General Public License    #
#  along with this library; if not, write to the Free Software Foundation,     #
#  Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA               #
################################################################################

default: test

# OASIS_START
# DO NOT EDIT (digest: a3c674b4239234cbbe53afe090018954)

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

configure:
	$(SETUP) -configure $(CONFIGUREFLAGS)

.PHONY: build doc test all install uninstall reinstall clean distclean configure

# OASIS_STOP

# Deploy target
#  Deploy/release the software.

deploy:
	dispakan --verbose $(DEPLOY_FLAGS)

install-bin:
	ocaml  setup.ml -configure \
		--prefix / \
		--sysconfdir /etc \
		--destdir "$(DESTDIR)"
	ocaml setup.ml -build
	mkdir -p "$(DESTDIR)/lib/ocaml"
	env OCAMLFIND_DESTDIR="$(DESTDIR)/lib/ocaml" \
		ocaml setup.ml -install


.PHONY: deploy install-bin

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
	-@if command -v OCamlPrecommit > /dev/null; then \
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
	# TODO: use default headache and re-enable.
	#find ./ \
	#  -name _darcs -prune -false \
	#  -name .git -prune -false \
	#  -name .svn -prune -false \
	#  -o -name _build -prune -false \
	#  -o -name dist -prune -false \
	#  -o -name '*[^~]' -type f \
	#  | xargs /usr/bin/headache -h _header -c _headache.config

.PHONY: headache
