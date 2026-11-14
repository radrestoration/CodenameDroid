; The Apple IIgs loader's memory map, shared by stage 0 (boot.s), stage 1 (stage1.s) and the packer.
STAGE1        = $0A00           ; stage 1 is read here, just after the boot block ($0800-$09FF)
STAGE1_BLOCKS = 8               ; blocks 1 - 8 of the disk (4 KB; stage 1 itself must fit in $0A00-$19EF)
SPENTRY       = $19F0           ; word: the SmartPort dispatch address stage 0 found, for stage 1
BOUNCE        = $1A00           ; 512-byte buffer stage 1 reads each block into before copying it to its place
UNIT          = 1               ; the SmartPort unit (the first device on the slot's chain), as hfs-boot assumes
