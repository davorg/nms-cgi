#
# v2/package/formmail_modules/Makefile
#
# Makefile for the FormMail package with seperate modules
#

NAME=formmail_modules

MODULES=../../lib/CGI/NMS/Charset.pm         \
	../../lib/CGI/NMS/Validator.pm       \
	../../lib/CGI/NMS/Script.pm          \
	../../lib/CGI/NMS/Script/FormMail.pm \
	../../lib/CGI/NMS/Mailer.pm          \
	../../lib/CGI/NMS/Mailer/Sendmail.pm \
	../../lib/CGI/NMS/Mailer/SMTP.pm 

SOURCES=../../src/formmail/FormMail.pl       \
	../../src/formmail/README            \
	../../src/formmail/EXAMPLES          \
	../../buildtools/tarballs.pl         \
	Makefile $(MODULES)

PKGFILES=.pkg/FormMail.pl .pkg/MANIFEST .pkg/README .pkg/EXAMPLES .pkg/ChangeLog \
	 .pkg/lib/CGI/NMS/Charset.pm         \
	 .pkg/lib/CGI/NMS/Validator.pm       \
	 .pkg/lib/CGI/NMS/Script.pm          \
	 .pkg/lib/CGI/NMS/Script/FormMail.pm \
	 .pkg/lib/CGI/NMS/Mailer.pm          \
	 .pkg/lib/CGI/NMS/Mailer/Sendmail.pm \
	 .pkg/lib/CGI/NMS/Mailer/SMTP.pm 

######################################################################

TARBALLS=../../.tarballs/$(NAME).tar.gz ../../.tarballs/$(NAME).zip

$(TARBALLS): ../../.tarballs $(PKGFILES) ../../buildtools/tarballs.pl
	../../buildtools/tarballs.pl ../../.tarballs $(NAME) $(PKGFILES)

.pkg/FormMail.pl: .pkg ../../src/formmail/FormMail.pl
	cp ../../src/formmail/FormMail.pl .pkg/

.pkg/MANIFEST: .pkg
	touch .pkg/MANIFEST

.pkg/README: .pkg ../../src/formmail/README
	cp ../../src/formmail/README .pkg/

.pkg/EXAMPLES: .pkg ../../src/formmail/EXAMPLES
	cp ../../src/formmail/EXAMPLES .pkg/

.pkg/ChangeLog: .pkg $(SOURCES)
	../../buildtools/cvs2cl.pl --revisions -f .pkg/ChangeLog \
		$(SOURCES) 

.pkg:
	mkdir -p .pkg

.pkg/lib/CGI/NMS/Charset.pm: .pkg ../../lib/CGI/NMS/Charset.pm
	(cd ../.. && tar cf - lib/CGI/NMS/Charset.pm) | (cd .pkg && tar xf -)

.pkg/lib/CGI/NMS/Validator.pm: .pkg ../../lib/CGI/NMS/Validator.pm
	(cd ../.. && tar cf - lib/CGI/NMS/Validator.pm) | (cd .pkg && tar xf -)

.pkg/lib/CGI/NMS/Script.pm: .pkg ../../lib/CGI/NMS/Script.pm
	(cd ../.. && tar cf - lib/CGI/NMS/Script.pm) | (cd .pkg && tar xf -)

.pkg/lib/CGI/NMS/Script/FormMail.pm: .pkg ../../lib/CGI/NMS/Script/FormMail.pm
	(cd ../.. && tar cf - lib/CGI/NMS/Script/FormMail.pm) | (cd .pkg && tar xf -)

.pkg/lib/CGI/NMS/Mailer.pm: .pkg ../../lib/CGI/NMS/Mailer.pm
	(cd ../.. && tar cf - lib/CGI/NMS/Mailer.pm) | (cd .pkg && tar xf -)

.pkg/lib/CGI/NMS/Mailer/Sendmail.pm: .pkg ../../lib/CGI/NMS/Mailer/Sendmail.pm
	(cd ../.. && tar cf - lib/CGI/NMS/Mailer/Sendmail.pm) | (cd .pkg && tar xf -)

.pkg/lib/CGI/NMS/Mailer/SMTP.pm: .pkg ../../lib/CGI/NMS/Mailer/SMTP.pm
	(cd ../.. && tar cf - lib/CGI/NMS/Mailer/SMTP.pm) | (cd .pkg && tar xf -)

../../.tarballs:
	mkdir -p ../../.tarballs

clean:
	rm -rf .pkg ../../.tarballs/$(NAME).*

.PHONY: clean

