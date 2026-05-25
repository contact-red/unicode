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

ci: unit-tests

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

.PHONY: all ci test unit-tests clean realclean dependencies docs
