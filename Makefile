TARGETDIR = drink
SRCDIR = src

IBA_DIR = $(TARGETDIR)/IBA
MCAH_FILE = $(TARGETDIR)/MCAH/Cocktails.md
MCAH_REPOSITORY = $(SRCDIR)/daveturnbull.git
TARGETS = $(IBA_DIR) $(MCAH_FILE)

all: bundle iba mcah | $(TARGETDIR)

test: bundle
	bundle exec ruby -Ilib bin/iba build $(IBA_DIR) SAZERAC

clean:
	rm -rf ${SRCDIR} ${TARGETS}

bundle:
	bundle install --quiet

iba: | $(IBA_DIR)

$(IBA_DIR):
	bundle exec ruby -Ilib bin/iba build $@

mcah: $(MCAH_FILE)

$(MCAH_REPOSITORY):
	git clone -q git://github.com/daveturnbull/cocktails.git $@

$(MCAH_FILE): | $(MCAH_REPOSITORY)
	mkdir -p $(TARGETDIR)/MCAH
	cp $(MCAH_REPOSITORY)/Cocktails.md $@
