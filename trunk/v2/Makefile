#
#  See README.developer.pod
#
##################################################################
#
# Testing
# =======
#
# To run regression tests against your working copy of the
# sources (before checking them in), you can use the following
# make targets:
#
#   test_formmail
#   multitest_formmail
#
#   test_all
#   multitest_all
#
# Those are 'train friendly' targets, i.e. they don't require a
# network connection.  The multitest_* targets repeat the test
# for all available perl interpreters, whereas the test_* targets
# don't.
#
##################################################################
#
# Release Management
# ==================
#
# The release_* and upload_* targets in this Makefile handle the
# generation of NMS packages from the source files under /v2
#
# The upload_* targets are exactly the same as the corresponding
# release_* targets, except that they upload the packages to the
# web site at the end.
#
# The release_* and upload_* targets will exit with an error
# message unless /v2 of your CVS tree is in date, with all
# modifications checked in.
#
# ChangeLog files are generated from CVS logs, and the various
# different packages are pulled together by /v2/package/*/Makefile
# and scripts in /v2/buildtools/.
#
# As part of the release process, each package file is extracted
# to a temporary location and the regression tests are run against
# the extracted files directly.
#
# There is quite a lot of caching to save time:
#
#   ChangeLog segments for each source file are cached under
#   /v2/.changelog, so there'll only be one remote 'cvs log'
#   command per source file changed since the last release.
#
#   The package files themselves are cached in /v2/.tarballs
#   and only rebuilt when there's a change to a source file or
#   build tool on which that package depends.
#
#   Each time a regression test is successfully run against a
#   package archive, an empty file in /v2/.testok is touched.
#   This allows the tests to be skipped if that package archive
#   hasn't changed since the tests were last run.
#
# The upload_* and release_* targets defined so far are:
#
#   formmail_modules  # formmail package with separate .pm files
#   formmail_compat   # formmail package with modules inlined
#   formmail          # equivalent to both of the above
#
###################################################################

test_all: test_formmail

multitest_all: multitest_formmail

test_formmail:
	NMSTEST_USE_LIB="$(NMS_WORKING_COPY)/v2/lib" buildtools/run_tests formmail

multitest_formmail:
	NMSTEST_USE_LIB="$(NMS_WORKING_COPY)/v2/lib" \
		sh -e -c 'for NMS_TEST_PERL in $(NMS_TEST_PERL) $(NMS_MORE_TEST_PERLS); \
		do echo; echo $$NMS_TEST_PERL; echo; buildtools/run_tests formmail; done'
	
.PHONY: test_all multitest_all test_formmail multitest_formmail

###################################################################

upload_formmail: release_formmail upload_formmail_modules \
		 upload_formmail_compat

release_formmail: release_formmail_modules release_formmail_compat

.PHONY: release_formmail upload_formmail

###################################################################

upload_formmail_modules: release_formmail_modules
	buildtools/upload .tarballs/formmail_modules

release_formmail_modules: indate                       \
                          formmail_modules_tarballs    \
                          .testok/formmail_modules_tgz \
                          .testok/formmail_modules_zip \

formmail_modules_tarballs:
	cd package/formmail_modules && make tarballs

.testok/formmail_modules_tgz: .tarballs/formmail_modules.tar.gz
	rm -rf .tarballs/formmail .tarballs/formmail_modules
	cd .tarballs && gzip -dc formmail_modules.tar.gz | tar xf -
	mv .tarballs/formmail_modules .tarballs/formmail
	perl -i -pe 's|^# use lib.*|use lib "$(NMS_WORKING_COPY)/v2/.tarballs/formmail/lib";|' \
		.tarballs/formmail/FormMail.pl
	# NMSTEST_SRCDIR="$(NMS_WORKING_COPY)/v2/.tarballs" buildtools/run_tests formmail
	NMSTEST_SRCDIR="$(NMS_WORKING_COPY)/v2/.tarballs" make multitest_formmail
	rm -rf .tarballs/formmail
	touch $@

.testok/formmail_modules_zip: .tarballs/formmail_modules.zip
	rm -rf .tarballs/formmail .tarballs/formmail_modules
	cd .tarballs && unzip formmail_modules.zip
	mv .tarballs/formmail_modules .tarballs/formmail
	perl -i -pe 's|^# use lib.*|use lib "$(NMS_WORKING_COPY)/v2/.tarballs/formmail/lib";|' \
		.tarballs/formmail/FormMail.pl
	# NMSTEST_SRCDIR="$(NMS_WORKING_COPY)/v2/.tarballs" buildtools/run_tests formmail
	NMSTEST_SRCDIR="$(NMS_WORKING_COPY)/v2/.tarballs" make multitest_formmail
	rm -rf .tarballs/formmail
	touch $@

.PHONY: upload_formmail_modules   \
	release_formmail_modules  \
	formmail_modules_tarballs

###################################################################

upload_formmail_compat: release_formmail_compat
	buildtools/upload .tarballs/formmail_compat

release_formmail_compat: indate                      \
                         formmail_compat_tarballs    \
                         .testok/formmail_compat_tgz \
                         .testok/formmail_compat_zip \

formmail_compat_tarballs:
	cd package/formmail_compat && make tarballs

.testok/formmail_compat_tgz: .tarballs/formmail_compat.tar.gz
	rm -rf .tarballs/formmail .tarballs/formmail_compat
	cd .tarballs && gzip -dc formmail_compat.tar.gz | tar xf -
	mv .tarballs/formmail_compat .tarballs/formmail
	NMSTEST_SRCDIR="$(NMS_WORKING_COPY)/v2/.tarballs" buildtools/run_tests formmail
	rm -rf .tarballs/formmail
	touch $@

.testok/formmail_compat_zip: .tarballs/formmail_compat.zip
	rm -rf .tarballs/formmail .tarballs/formmail_compat
	cd .tarballs && unzip formmail_compat.zip
	mv .tarballs/formmail_compat .tarballs/formmail
	NMSTEST_SRCDIR="$(NMS_WORKING_COPY)/v2/.tarballs" buildtools/run_tests formmail
	rm -rf .tarballs/formmail
	touch $@

.PHONY: upload_formmail_compat   \
	release_formmail_compat  \
	formmail_compat_tarballs

###################################################################

MAKEFILE_SEGMENTS = buildtools/ChangeLog.mak buildtools/libfiles.mak

$(MAKEFILE_SEGMENTS): buildtools/generate_makefile_segments
	cd buildtools && ./generate_makefile_segments

indate: $(MAKEFILE_SEGMENTS)
	cvs diff >/dev/null 2>&1 || (echo;echo First Get CVS in date;echo;false)

clean:
	rm -f .testok/* .tarballs/* $(MAKEFILE_SEGMENTS)
	rm -rf .changelog/* packages/*/.pkg

.PHONY: indate clean

