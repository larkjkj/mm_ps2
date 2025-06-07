# nothing still
PLATFORM		?= PS2
VERSION			:= n64-us

BASEROM_DIR		?= baseroms/$(VERSION)
BUILD_DIR		?= build/$(VERSION)
EXTRACTED_DIR	?= extracted/$(VERSION)

BINARY			:= zelda-$(VERSION).elf
LDSCRIPT		:= $(BINARY:.elf=.ld)

MKLDSCRIPT		:= tools/buildtools/mkldscript
NON_MATCHING	?= 1

# i guess ld final files are not really necessary, for linker-only probally
LD_FF 	:= $(foreach f,$(shell find linker_scripts/final/*.ld),$(BUILD_DIR)/$f)
SPEC			:= spec/spec
SPEC_INCLUDES	:= $(wildcard spec/*)
BUILD_DIR_REPLACE := sed -e 's|$$(BUILD_DIR)|$(BUILD_DIR)|g'
INCS			:= -Iinclude -I.

ifeq ($(PLATFORM),PS2)
	PREF    := mips64r5900el-ps2-elf-

	CC      := $(PREF)gcc
	LD      := $(PREF)ld
	NM      := $(PREF)nm
	AS      := $(PREF)as
	CPP     := $(PREF)cpp
	LINK    := $(PS2SDK)/ee/startup/linkfile

	CPPFLAGS    +=  -DCOMPILER_GCC -DNON_MATCHING -DAVOID_UB \
					-P -xc -fno-dollars-in-identifiers

	INCS    +=  -I$(PS2SDK)/ee/include \
				-I$(PS2SDK)/common/include \
				-I$(PS2SDK)/ports/include \
				-I$(GSKIT)/include
endif

SOURCE_DIR		:= src

SOURCE_C		:= $(foreach f,$(SOURCE_DIR),$(wildcard $(f)/*/*.c))
SOURCE_S		:= $(foreach f,$(SOURCE_DIR),$(wildcard $(f)/*/*.s))

OBJ_FILES		:=	$(patsubst %.c,$(BUILD_DIR)/%.o,$(SOURCE_C)) \
					$(patsubst %.s,$(BUILD_DIR)/%.o,$(SOURCE_S))

CFLAGS			:= -DNON_MATCHING=$(NON_MATCHING)

all: setup $(OBJ_FILES)

setup:
	python extract_baserom.py
	python extract_incbins.py
	python extract_assets.py

$(BUILD_DIR)/spec: $(SPEC) $(SPEC_INCLUDES)
	@test -d $(BUILD_DIR) || mkdir $(BUILD_DIR) || continue;
	$(CPP) $(CPPFLAGS) -I. $< | $(BUILD_DIR_REPLACE) > $@

$(LDSCRIPT): $(BUILD_DIR)/spec
	$(MKLDSCRIPT) $< $@

$(BUILD_DIR)/%.o: %.c
	@test -d $(BUILD_DIR) || mkdir $(@D) || continue;
	$(CC) $(CFLAGS) $(INCS) -o $(@D) -c $<

$(BINARY): $(OBJ_FILES) $(LDSCRIPT)
	$(LD) -T$(LINK) -T$(BUILD_DIR)/spec -T$(LDSCRIPT) -T$(LD_FF)
