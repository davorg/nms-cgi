####################################################################
#
# v2/buildtools/package.mak
#
# Makefile component for all packages.
#
# Imports from parent Makefile:
#
# NAME
#     package name, e.g. "formmail_modules".
#
# MODULES
#     A list of the modules to go in the package, paths relative
#     to /v2/lib in the CVS tree.
#
# SOURCE_FILES
#     A list of the files on which the package contents depend,
#     paths relative to /v2 in the CVS tree.
#
# PKGFILES
#     A list of the files to go in the package, relative to the
#     root directory of the package archive.
#

FILES_IN_PKG_DIR = $(PKGFILES:%=.pkg/%)

TARBALLS=../../.tarballs/$(NAME).tar.gz \
	 ../../.tarballs/$(NAME).zip    \
	 ../../.tarballs/$(NAME).VER

$(TARBALLS): $(FILES_IN_PKG_DIR) .pkg/VERSION ../../buildtools/tarballs
	mkdir -p ../../.tarballs
	../../buildtools/tarballs ../../.tarballs $(NAME) $(FILES_IN_PKG_DIR)
	cp .pkg/VERSION ../../.tarballs/$(NAME).VER

tarballs: $(TARBALLS)

.pkg:
	mkdir -p .pkg

.pkg/MANIFEST: .pkg
	touch .pkg/MANIFEST

.pkg/VERSION: .pkg .pkg/ChangeLog
	../../buildtools/cl2ver .pkg/ChangeLog .pkg/VERSION

clean:
	rm -rf .pkg $(TARBALLS)

.PHONY: clean tarballs

include ../../buildtools/ChangeLog.mak

