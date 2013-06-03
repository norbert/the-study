TARGETDIR = drink
IBADIR = $(TARGETDIR)/IBA

all: iba | $(TARGETDIR)

clean:
	rm -rf ${TARGETDIR}

bundle:
	bundle install --quiet

iba: | $(IBADIR)

$(IBADIR):
	bundle exec ruby -Ilib bin/iba build $@
