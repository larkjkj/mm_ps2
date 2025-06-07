# nothing still
PLATFORM		?= PS2
VERSION			:= n64-us


LIBULTRA_A		:= libultra64.a

BASEROM_DIR		?= baseroms/$(VERSION)
BUILD_DIR		?= build/$(VERSION)
EXTRACTED_DIR	?= extracted/$(VERSION)


LIBULTRA_DIR	:= src/libultra
LIBULTRA_SRC_C	:= $(foreach lu,$(LIBULTRA_DIR),$(wildcard $(lu)/*/*.c))
LIBULTRA_SRC_S	:= $(foreach lu,$(LIBULTRA_DIR),$(wildcard $(lu)/*/*.s))
LIBULTRA_OBJS	:=	$(patsubst %.c,$(BUILD_DIR)/%.o,$(LIBULTRA_SRC_C)) \
					$(patsubst %.s,$(BUILD_DIR)/%.o,$(LIBULTRA_SRC_S))

BINARY			:= zelda-$(VERSION).elf
LDSCRIPT		:= $(BINARY:.elf=.ld)

MKLDSCRIPT		:= tools/buildtools/mkldscript
NON_MATCHING	?= 1

# i guess ld final files are not really necessary, for linker-only probally
LD_FF 	:= $(foreach f,$(shell find linker_scripts/final/*.ld),$(BUILD_DIR)/$f)
SPEC			:= spec/spec
SPEC_INCLUDES	:= $(wildcard spec/*)
BUILD_DIR_REPLACE := sed -e 's|$$(BUILD_DIR)|$(BUILD_DIR)|g'
INCS			:= -Iinclude -I. -I$(EXTRACTED_DIR)

ifeq ($(PLATFORM),PS2)
	PREF    := mips64r5900el-ps2-elf-

	CC      := $(PREF)gcc
	LD      := $(PREF)ld
	NM      := $(PREF)nm
	AS      := $(PREF)as
	CPP     := $(PREF)cpp
	LINK    := $(PS2SDK)/ee/startup/linkfile
	PYTHON  := python3

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

all: $(LIBULTRA_OBJS)

setup:
	$(PYTHON) tools/decompress_baserom.py
	$(PYTHON) tools/decompress_baserom.py -v $(VERSION)
	$(PYTHON) tools/extract_baserom.py $(BASEROM_DIR)/baserom-decompressed.z64 $(EXTRACTED_DIR)/baserom -v $(VERSION)
	$(PYTHON) tools/extract_incbins.py $(EXTRACTED_DIR)/baserom $(EXTRACTED_DIR)/incbin -v $(VERSION)
	$(PYTHON) tools/extract_yars.py $(EXTRACTED_DIR)/baserom -v $(VERSION)

assets:
	$(PYTHON) tools/extract_assets.py $(EXTRACTED_DIR)/baserom $(EXTRACTED_DIR)/assets -j9 -Z Wno-hardcoded-pointer -v $(VERSION)
	$(PYTHON) tools/extract_text.py $(EXTRACTED_DIR)/baserom $(EXTRACTED_DIR)/text -v $(VERSION)
	$(PYTHON) tools/extract_audio.py -b $(EXTRACTED_DIR)/baserom -o $(EXTRACTED_DIR) -v $(VERSION) --read-xml

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


$(LIBULTRA_OBJS): %.c
	$(CC) -o $@ -c $<

$(LIBULTRA_A): $(LIBULTRA_OBJS)
	$(AR) rcs $@ $?
