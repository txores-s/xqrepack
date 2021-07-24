FIRMWARES:=$(shell cd orig-firmwares; ls *.bin | sed 's/\.bin$$//')

TARGETS_SSH:=$(patsubst %,%+SSH+$(FIRMWARE_SLUG).bin,$(FIRMWARES))
TARGETS_SSH_MI:=$(patsubst %,%+SSH+MI+$(FIRMWARE_SLUG).bin,$(FIRMWARES))
TARGETS_SSH_MI_OPT:=$(patsubst %,%+SSH+MI+opt+$(FIRMWARE_SLUG).bin,$(FIRMWARES))
TARGETS_SSH_OPT:=$(patsubst %,%+SSH+opt+$(FIRMWARE_SLUG).bin,$(FIRMWARES))
TARGETS:=$(shell echo $(TARGETS_SSH) $(TARGETS_SSH_MI) $(TARGETS_SSH_MI_OPT) $(TARGETS_SSH_OPT) | sed 's/ /\n/g' | sort)

all: $(TARGETS)

# ubifs

ubifs-root/%: orig-firmwares/%
	-rm -rf $@
	ubireader_extract_images -w orig-firmwares/$*

ubifs-kernel/%: ubifs-root/%
	-rm -rf $@
	mkdir -p $@
	mv ubifs-root/$*/img-*_vol-kernel.ubifs $@

# unsquashfs

unsquashfs-root/%: ubifs-kernel/% ubifs-root/%
	-rm -rf $@
	mkdir -p $@
	unsquashfs -f -d $@ ubifs-root/$*/img-*_vol-ubi_rootfs.ubifs
	rm -rf ubifs-root/$*

# tar

tar-root:
	mkdir -p $@

tar-root/%: unsquashfs-root/% tar-root
	-rm -rf $@
	tar cf $@ -C unsquashfs-root/$* .
	rm -rf unsquashfs-root/$*

# squashfs

squashfs-root:
	mkdir -p $@

squashfs-root/%+SSH+$(FIRMWARE_SLUG).bin: tar-root/%.bin squashfs-root
	-rm -rf $@
	mkdir -p $@
	tar xf tar-root/$*.bin -C squashfs-root/$*+SSH+$(FIRMWARE_SLUG).bin --strip-components=1

squashfs-root/%+SSH+MI+$(FIRMWARE_SLUG).bin: tar-root/%.bin squashfs-root
	-rm -rf $@
	mkdir -p $@
	tar xf tar-root/$*.bin -C squashfs-root/$*+SSH+MI+$(FIRMWARE_SLUG).bin --strip-components=1

squashfs-root/%+SSH+MI+opt+$(FIRMWARE_SLUG).bin: tar-root/%.bin squashfs-root
	-rm -rf $@
	mkdir -p $@
	tar xf tar-root/$*.bin -C squashfs-root/$*+SSH+MI+opt+$(FIRMWARE_SLUG).bin --strip-components=1

squashfs-root/%+SSH+opt+$(FIRMWARE_SLUG).bin: tar-root/%.bin squashfs-root
	-rm -rf $@
	mkdir -p $@
	tar xf tar-root/$*.bin -C squashfs-root/$*+SSH+opt+$(FIRMWARE_SLUG).bin --strip-components=1

# mksquashfs

mksquashfs-root:
	mkdir -p $@

mksquashfs-root/%+SSH+$(FIRMWARE_SLUG).bin.new: squashfs-root/%+SSH+$(FIRMWARE_SLUG).bin mksquashfs-root
	-rm -rf $@
	FSDIR=squashfs-root/$*+SSH+$(FIRMWARE_SLUG).bin ./repack-squashfs.sh mksquashfs-root/$*+SSH+$(FIRMWARE_SLUG).bin
	rm -rf squashfs-root/$*+SSH+$(FIRMWARE_SLUG).bin

mksquashfs-root/%+SSH+MI+$(FIRMWARE_SLUG).bin.new: squashfs-root/%+SSH+MI+$(FIRMWARE_SLUG).bin mksquashfs-root
	-rm -rf $@
	FSDIR=squashfs-root/$*+SSH+MI+$(FIRMWARE_SLUG).bin ./repack-squashfs-mi.sh mksquashfs-root/$*+SSH+MI+$(FIRMWARE_SLUG).bin
	rm -rf squashfs-root/$*+SSH+MI+$(FIRMWARE_SLUG).bin

mksquashfs-root/%+SSH+MI+opt+$(FIRMWARE_SLUG).bin.new: squashfs-root/%+SSH+MI+opt+$(FIRMWARE_SLUG).bin mksquashfs-root
	-rm -rf $@
	FSDIR=squashfs-root/$*+SSH+MI+opt+$(FIRMWARE_SLUG).bin ./repack-squashfs-mi-opt.sh mksquashfs-root/$*+SSH+MI+opt+$(FIRMWARE_SLUG).bin
	rm -rf squashfs-root/$*+SSH+MI+opt+$(FIRMWARE_SLUG).bin

mksquashfs-root/%+SSH+opt+$(FIRMWARE_SLUG).bin.new: squashfs-root/%+SSH+opt+$(FIRMWARE_SLUG).bin mksquashfs-root
	-rm -rf $@
	FSDIR=squashfs-root/$*+SSH+opt+$(FIRMWARE_SLUG).bin ./repack-squashfs-opt.sh mksquashfs-root/$*+SSH+opt+$(FIRMWARE_SLUG).bin
	rm -rf squashfs-root/$*+SSH+opt+$(FIRMWARE_SLUG).bin

# ubi

%+SSH+$(FIRMWARE_SLUG).bin: mksquashfs-root/%+SSH+$(FIRMWARE_SLUG).bin.new repack-squashfs.sh ubifs-kernel/%.bin
	rm -f $@
	OUTPUT=$@ ./ubinize.sh ubifs-kernel/$*.bin/img-*_vol-kernel.ubifs mksquashfs-root/$@.new
	rm -rf mksquashfs-root/$@.new

%+SSH+MI+$(FIRMWARE_SLUG).bin: mksquashfs-root/%+SSH+MI+$(FIRMWARE_SLUG).bin.new repack-squashfs-mi.sh ubifs-kernel/%.bin
	rm -f $@
	OUTPUT=$@ ./ubinize.sh ubifs-kernel/$*.bin/img-*_vol-kernel.ubifs mksquashfs-root/$@.new
	rm -rf mksquashfs-root/$@.new

%+SSH+MI+opt+$(FIRMWARE_SLUG).bin: mksquashfs-root/%+SSH+MI+opt+$(FIRMWARE_SLUG).bin.new repack-squashfs-mi-opt.sh ubifs-kernel/%.bin
	rm -f $@
	OUTPUT=$@ ./ubinize.sh ubifs-kernel/$*.bin/img-*_vol-kernel.ubifs mksquashfs-root/$@.new
	rm -rf mksquashfs-root/$@.new

%+SSH+opt+$(FIRMWARE_SLUG).bin: mksquashfs-root/%+SSH+opt+$(FIRMWARE_SLUG).bin.new repack-squashfs-opt.sh ubifs-kernel/%.bin
	rm -f $@
	OUTPUT=$@ ./ubinize.sh ubifs-kernel/$*.bin/img-*_vol-kernel.ubifs mksquashfs-root/$@.new
	rm -rf mksquashfs-root/$@.new
