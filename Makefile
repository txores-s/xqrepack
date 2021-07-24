FIRMWARES:=$(shell cd orig-firmwares; ls *.bin | sed 's/\.bin$$//')

TARGETS_SSH:=$(patsubst %,%+SSH+$(FIRMWARE_SLUG).bin,$(FIRMWARES))
TARGETS_SSH_MI:=$(patsubst %,%+SSH+MI+$(FIRMWARE_SLUG).bin,$(FIRMWARES))
TARGETS_SSH_MI_OPT:=$(patsubst %,%+SSH+MI+opt+$(FIRMWARE_SLUG).bin,$(FIRMWARES))
TARGETS_SSH_OPT:=$(patsubst %,%+SSH+opt+$(FIRMWARE_SLUG).bin,$(FIRMWARES))
TARGETS:=$(shell echo $(TARGETS_SSH) $(TARGETS_SSH_MI) $(TARGETS_SSH_MI_OPT) $(TARGETS_SSH_OPT) | sed 's/ /\n/g' | sort)

all: $(TARGETS)

%+SSH+$(FIRMWARE_SLUG).bin: orig-firmwares/%.bin repack-squashfs.sh
	rm -f $@
	-rm -rf ubifs-root/$@ squashfs-root/$@
	ubireader_extract_images -w -o ubifs-root/$@ orig-firmwares/$*.bin
	mkdir -p squashfs-root/$@
	FSDIR=squashfs-root/$@ fakeroot -- ./repack-squashfs.sh ubifs-root/$@/$*.bin/img-*_vol-ubi_rootfs.ubifs
	OUTPUT=$@ ./ubinize.sh ubifs-root/$@/$*.bin/img-*_vol-kernel.ubifs ubifs-root/$@/$*.bin/img-*_vol-ubi_rootfs.ubifs.new
	rm -rf ubifs-root/$@ squashfs-root/$@

%+SSH+MI+$(FIRMWARE_SLUG).bin: orig-firmwares/%.bin repack-squashfs-mi.sh
	rm -f $@
	-rm -rf ubifs-root/$@ squashfs-root/$@
	ubireader_extract_images -w -o ubifs-root/$@ orig-firmwares/$*.bin
	mkdir -p squashfs-root/$@
	FSDIR=squashfs-root/$@ fakeroot -- ./repack-squashfs-mi.sh ubifs-root/$@/$*.bin/img-*_vol-ubi_rootfs.ubifs
	OUTPUT=$@ ./ubinize.sh ubifs-root/$@/$*.bin/img-*_vol-kernel.ubifs ubifs-root/$@/$*.bin/img-*_vol-ubi_rootfs.ubifs.new
	rm -rf ubifs-root/$@ squashfs-root/$@

%+SSH+MI+opt+$(FIRMWARE_SLUG).bin: orig-firmwares/%.bin repack-squashfs-mi-opt.sh
	rm -f $@
	-rm -rf ubifs-root/$@ squashfs-root/$@
	ubireader_extract_images -w -o ubifs-root/$@ orig-firmwares/$*.bin
	mkdir -p squashfs-root/$@
	FSDIR=squashfs-root/$@ fakeroot -- ./repack-squashfs-mi-opt.sh ubifs-root/$@/$*.bin/img-*_vol-ubi_rootfs.ubifs
	OUTPUT=$@ ./ubinize.sh ubifs-root/$@/$*.bin/img-*_vol-kernel.ubifs ubifs-root/$@/$*.bin/img-*_vol-ubi_rootfs.ubifs.new
	rm -rf ubifs-root/$@ squashfs-root/$@

%+SSH+opt+$(FIRMWARE_SLUG).bin: orig-firmwares/%.bin repack-squashfs-opt.sh
	rm -f $@
	-rm -rf ubifs-root/$@ squashfs-root/$@
	ubireader_extract_images -w -o ubifs-root/$@ orig-firmwares/$*.bin
	mkdir -p squashfs-root/$@
	FSDIR=squashfs-root/$@ fakeroot -- ./repack-squashfs-opt.sh ubifs-root/$@/$*.bin/img-*_vol-ubi_rootfs.ubifs
	OUTPUT=$@ ./ubinize.sh ubifs-root/$@/$*.bin/img-*_vol-kernel.ubifs ubifs-root/$@/$*.bin/img-*_vol-ubi_rootfs.ubifs.new
	rm -rf ubifs-root/$@ squashfs-root/$@
