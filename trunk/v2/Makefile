
####################################################################
#
# Build the tarballs
#

test_formmail: test_formmail_modules test_formmail_compat

###################################################################

test_formmail_modules: formmail_modules_tarballs .testok/formmail_modules

formmail_modules_tarballs:
	cd package/formmail_modules && make tarballs

.testok/formmail_modules: .tarballs/formmail_modules.tar.gz
	rm -rf .tarballs/formmail .tarballs/formmail_modules
	cd .tarballs && gzip -dc formmail_modules.tar.gz | tar xf -
	mv .tarballs/formmail_modules .tarballs/formmail
	perl -i -pe 's|^# use lib.*|use lib "$(NMS_WORKING_COPY)/v2/.tarballs/formmail/lib";|' \
		.tarballs/formmail/FormMail.pl
	NMSTEST_SRCDIR="$(NMS_WORKING_COPY)/v2/.tarballs" buildtools/run_tests formmail
	rm -rf .tarballs/formmail
	touch $@

.PHONY: test_formmail_modules formmail_modules_tarballs

#####################################################################

test_formmail_compat: formmail_compat_tarballs .testok/formmail_compat

formmail_compat_tarballs:
	cd package/formmail_compat && make tarballs

.testok/formmail_compat: .tarballs/formmail.tar.gz
	rm -rf .tarballs/formmail
	cd .tarballs && gzip -dc formmail.tar.gz | tar xf -
	NMSTEST_SRCDIR="$(NMS_WORKING_COPY)/v2/.tarballs" buildtools/run_tests formmail
	rm -rf .tarballs/formmail
	touch $@

.PHONY: test_formmail_compat  formmail_compat_tarballs

#####################################################################




