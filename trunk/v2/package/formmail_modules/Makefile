#
# v2/package/formmail_modules/Makefile
#
# Makefile for the FormMail package with seperate modules
#

NAME = formmail_modules

MODULES = \
	CGI/NMS/Charset.pm         \
	CGI/NMS/Validator.pm       \
	CGI/NMS/Script.pm          \
	CGI/NMS/Script/FormMail.pm \
	CGI/NMS/Mailer.pm          \
	CGI/NMS/Mailer/Sendmail.pm \
	CGI/NMS/Mailer/SMTP.pm

SOURCE_FILES = \
	src/formmail/FormMail.pl        \
	src/formmail/README             \
	src/formmail/EXAMPLES           \
	buildtools/tarballs             \
	package/$(NAME)/Makefile        \
	package/$(NAME)/README.install  \
	package/$(NAME)/README.manifest \
	$(MODULES:%=lib/%)

PKGFILES = FormMail.pl README EXAMPLES ChangeLog MANIFEST $(MODULES:%=lib/%)

######################################################################

FILES_IN_PKG_DIR = $(PKGFILES:%=.pkg/%)

TARBALLS=../../.tarballs/$(NAME).tar.gz ../../.tarballs/$(NAME).zip
tarballs: $(TARBALLS)

$(TARBALLS): $(FILES_IN_PKG_DIR) ../../buildtools/tarballs
	mkdir -p ../../.tarballs
	../../buildtools/tarballs ../../.tarballs $(NAME) $(FILES_IN_PKG_DIR)

.pkg/FormMail.pl: ../../src/formmail/FormMail.pl
	mkdir -p .pkg
	cp ../../src/formmail/FormMail.pl .pkg/

.pkg/MANIFEST:
	mkdir -p .pkg
	touch .pkg/MANIFEST

.pkg/README: ../../src/formmail/README README.manifest README.install
	mkdir -p .pkg
	../../buildtools/template ../../src/formmail/README >$@

.pkg/EXAMPLES: ../../src/formmail/EXAMPLES
	mkdir -p .pkg
	cp ../../src/formmail/EXAMPLES .pkg/

include ../../buildtools/ChangeLog.mak

.pkg/lib/CGI/NMS/Charset.pm: ../../lib/CGI/NMS/Charset.pm
	mkdir -p .pkg
	(cd ../.. && tar cf - lib/CGI/NMS/Charset.pm) | (cd .pkg && tar xf -)

.pkg/lib/CGI/NMS/Validator.pm: ../../lib/CGI/NMS/Validator.pm
	mkdir -p .pkg
	(cd ../.. && tar cf - lib/CGI/NMS/Validator.pm) | (cd .pkg && tar xf -)

.pkg/lib/CGI/NMS/Script.pm: ../../lib/CGI/NMS/Script.pm
	mkdir -p .pkg
	(cd ../.. && tar cf - lib/CGI/NMS/Script.pm) | (cd .pkg && tar xf -)

.pkg/lib/CGI/NMS/Script/FormMail.pm: ../../lib/CGI/NMS/Script/FormMail.pm
	mkdir -p .pkg
	(cd ../.. && tar cf - lib/CGI/NMS/Script/FormMail.pm) | (cd .pkg && tar xf -)

.pkg/lib/CGI/NMS/Mailer.pm: ../../lib/CGI/NMS/Mailer.pm
	mkdir -p .pkg
	(cd ../.. && tar cf - lib/CGI/NMS/Mailer.pm) | (cd .pkg && tar xf -)

.pkg/lib/CGI/NMS/Mailer/Sendmail.pm: ../../lib/CGI/NMS/Mailer/Sendmail.pm
	mkdir -p .pkg
	(cd ../.. && tar cf - lib/CGI/NMS/Mailer/Sendmail.pm) | (cd .pkg && tar xf -)

.pkg/lib/CGI/NMS/Mailer/SMTP.pm: ../../lib/CGI/NMS/Mailer/SMTP.pm
	mkdir -p .pkg
	(cd ../.. && tar cf - lib/CGI/NMS/Mailer/SMTP.pm) | (cd .pkg && tar xf -)

clean:
	rm -rf .pkg ../../.tarballs/$(NAME).tar.gz ../../.tarballs/$(NAME).zip

.PHONY: clean tarballs


