SRCDIR ?= src
TARGETDIR = $(SRCDIR)

IBA_TARGET = $(TARGETDIR)/drink/IBA
TARGETS = $(IBA_TARGET)

all: bundle iba menu | $(TARGETDIR)

menu: iba
	find $(SRCDIR) $(IBA_TARGET) -maxdepth 1 -type f | \
		sed -e 's/$(TARGETDIR)\///' -e 's/\.md//' | \
		sed -e 's/\// \/ /g'

test: test-iba
test-iba: bundle
	bundle exec ruby bin/iba update $(IBA_TARGET) SAZERAC
	cat $(IBA_TARGET)/Sazerac.md

clean:
	rm -rf $(TARGETS)

bundle:
	bundle install --quiet

iba: | $(IBA_TARGET)
$(IBA_TARGET):
	bundle exec ruby -Ilib bin/iba update $@
