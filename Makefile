config ?= debug
static ?= false
linker ?=

PACKAGE := unicode
GET_DEPENDENCIES_WITH := corral fetch
CLEAN_DEPENDENCIES_WITH := corral clean
PONYC ?= ponyc
COMPILE_WITH := corral run -- $(PONYC)
BUILD_DOCS_WITH := corral run -- pony-doc

BUILD_DIR ?= build/$(config)
SRC_DIR ?= $(PACKAGE)
tests_binary := $(BUILD_DIR)/unicode
docs_dir := build/$(PACKAGE)-docs

ifdef config
	ifeq (,$(filter $(config),debug release))
		$(error Unknown configuration "$(config)")
	endif
endif

ifeq ($(config),release)
	PONYC = $(COMPILE_WITH)
else
	PONYC = $(COMPILE_WITH) --debug
endif

ifdef static
	ifeq (,$(filter $(static),true false))
		$(error "static must be true or false)
	endif
endif

ifeq ($(static),true)
	LINKER += --static
endif

ifneq ($(linker),)
	LINKER += --link-ldcmd=$(linker)
endif

PONYC := $(PONYC) $(LINKER)

SOURCE_FILES := $(shell find $(SRC_DIR) -name '*.pony')

all: ci

ci: unit-tests conform conform-grapheme conform-word conform-sentence conform-line

test: unit-tests

unit-tests: $(tests_binary)
	$^

$(tests_binary): $(SOURCE_FILES) | $(BUILD_DIR) dependencies
	$(PONYC) -o $(BUILD_DIR) $(SRC_DIR)/tests -b unicode

clean:
	$(CLEAN_DEPENDENCIES_WITH)
	rm -rf $(BUILD_DIR)

realclean:
	$(CLEAN_DEPENDENCIES_WITH)
	rm -rf build

$(docs_dir): $(SOURCE_FILES) dependencies
	rm -rf $(docs_dir)
	$(BUILD_DOCS_WITH) $(SRC_DIR) --output build

docs: $(docs_dir)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

dependencies: corral.json
	$(GET_DEPENDENCIES_WITH)

.PHONY: all ci test unit-tests clean realclean dependencies docs ucd-build ucd-generate ucd-download conform conform-build conform-grapheme conform-grapheme-build conform-word conform-word-build conform-sentence conform-sentence-build conform-line conform-line-build

.DEFAULT_GOAL := all

# ---------- UCD codegen ----------
# unicode-build is a separate Pony tool that reads UCD source files and
# emits the per-property tables into unicode/_ucd_*.pony.

UCD_DIR ?= ./ucd
# Pinned to a specific Unicode version so CI and local stay in sync.
# Bumping this is a deliberate, reviewed step: change the version,
# `make ucd-download && make ucd-generate`, commit the regenerated
# tables, and verify `make conform` still passes.
UCD_VERSION := 16.0.0
UCD_URL := https://www.unicode.org/Public/$(UCD_VERSION)/ucd

# Files we pull from the authoritative source. Split into top-level UCD,
# auxiliary, and emoji subdirectories per unicode.org layout.
UCD_TOPLEVEL := UnicodeData.txt CaseFolding.txt SpecialCasing.txt PropList.txt \
                Scripts.txt ScriptExtensions.txt DerivedCoreProperties.txt \
                DerivedNormalizationProps.txt CompositionExclusions.txt \
                NameAliases.txt LineBreak.txt EastAsianWidth.txt
UCD_AUXILIARY := GraphemeBreakProperty.txt WordBreakProperty.txt \
                 SentenceBreakProperty.txt \
                 GraphemeBreakTest.txt WordBreakTest.txt \
                 SentenceBreakTest.txt LineBreakTest.txt
UCD_EMOJI := emoji-data.txt
UCD_TESTS := NormalizationTest.txt

ucd-download: $(UCD_DIR)
	@echo "Fetching UCD files from $(UCD_URL)"
	@for f in $(UCD_TOPLEVEL) $(UCD_TESTS); do \
	  echo "  $$f"; \
	  curl -sSfL "$(UCD_URL)/$$f" -o "$(UCD_DIR)/$$f"; \
	done
	@mkdir -p $(UCD_DIR)/auxiliary
	@for f in $(UCD_AUXILIARY); do \
	  echo "  auxiliary/$$f"; \
	  curl -sSfL "$(UCD_URL)/auxiliary/$$f" -o "$(UCD_DIR)/auxiliary/$$f"; \
	done
	@mkdir -p $(UCD_DIR)/emoji
	@for f in $(UCD_EMOJI); do \
	  echo "  emoji/$$f"; \
	  curl -sSfL "$(UCD_URL)/emoji/$$f" -o "$(UCD_DIR)/emoji/$$f"; \
	done
	@echo "Done. UCD files in $(UCD_DIR)/"

$(UCD_DIR):
	mkdir -p $(UCD_DIR)

ucd_build_binary := $(BUILD_DIR)/unicode_build_main

ucd-build: $(ucd_build_binary)

$(ucd_build_binary): $(SOURCE_FILES) $(shell find unicode_build unicode_build_main -name '*.pony' 2>/dev/null) | $(BUILD_DIR) dependencies
	$(PONYC) -o $(BUILD_DIR) unicode_build_main -b unicode_build_main

ucd-generate: $(ucd_build_binary)
	$(ucd_build_binary) $(UCD_DIR) ./unicode

conform_binary := $(BUILD_DIR)/unicode_conform_main

conform-build: $(conform_binary)

$(conform_binary): $(SOURCE_FILES) $(shell find unicode_conform_main -name '*.pony' 2>/dev/null) | $(BUILD_DIR) dependencies
	$(PONYC) -o $(BUILD_DIR) unicode_conform_main -b unicode_conform_main

conform: $(conform_binary)
	$(conform_binary) $(UCD_DIR)/NormalizationTest.txt

conform_grapheme_binary := $(BUILD_DIR)/unicode_grapheme_conform_main

conform-grapheme-build: $(conform_grapheme_binary)

$(conform_grapheme_binary): $(SOURCE_FILES) $(shell find unicode_grapheme_conform_main -name '*.pony' 2>/dev/null) | $(BUILD_DIR) dependencies
	$(PONYC) -o $(BUILD_DIR) unicode_grapheme_conform_main -b unicode_grapheme_conform_main

conform-grapheme: $(conform_grapheme_binary)
	$(conform_grapheme_binary) $(UCD_DIR)/auxiliary/GraphemeBreakTest.txt

conform_word_binary := $(BUILD_DIR)/unicode_word_conform_main

conform-word-build: $(conform_word_binary)

$(conform_word_binary): $(SOURCE_FILES) $(shell find unicode_word_conform_main -name '*.pony' 2>/dev/null) | $(BUILD_DIR) dependencies
	$(PONYC) -o $(BUILD_DIR) unicode_word_conform_main -b unicode_word_conform_main

conform-word: $(conform_word_binary)
	$(conform_word_binary) $(UCD_DIR)/auxiliary/WordBreakTest.txt

conform_sentence_binary := $(BUILD_DIR)/unicode_sentence_conform_main

conform-sentence-build: $(conform_sentence_binary)

$(conform_sentence_binary): $(SOURCE_FILES) $(shell find unicode_sentence_conform_main -name '*.pony' 2>/dev/null) | $(BUILD_DIR) dependencies
	$(PONYC) -o $(BUILD_DIR) unicode_sentence_conform_main -b unicode_sentence_conform_main

conform-sentence: $(conform_sentence_binary)
	$(conform_sentence_binary) $(UCD_DIR)/auxiliary/SentenceBreakTest.txt

conform_line_binary := $(BUILD_DIR)/unicode_line_conform_main

conform-line-build: $(conform_line_binary)

$(conform_line_binary): $(SOURCE_FILES) $(shell find unicode_line_conform_main -name '*.pony' 2>/dev/null) | $(BUILD_DIR) dependencies
	$(PONYC) -o $(BUILD_DIR) unicode_line_conform_main -b unicode_line_conform_main

conform-line: $(conform_line_binary)
	$(conform_line_binary) $(UCD_DIR)/auxiliary/LineBreakTest.txt
