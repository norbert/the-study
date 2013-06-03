TARGETDIR = drink
IBADIR = $(TARGETDIR)/IBA

all: iba | $(TARGETDIR)

test:
	bundle exec ruby -Ilib bin/iba build $(IBADIR) SAZERAC

clean:
	rm -rf ${IBADIR}

bundle:
	bundle install --quiet

iba: | $(IBADIR)

$(IBADIR):
	bundle exec ruby -Ilib bin/iba build $@
