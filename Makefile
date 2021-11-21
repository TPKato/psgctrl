# TARGET = psg-test
TARGET = psgplay
F_CPU = 1000000

DEVICE = atmega48

AVRDUDE = avrdude
AVRWRITER = sparkfun
AVRDUDEBAUDRATE = 2400

MUSICDIR = mml
MUSIC = choral

AS = avra
ASFLAGS =

# ------------------------------------------------------------
.SUFFIXES: .asm .hex .mml

all: $(TARGET).hex

$(TARGET).hex: $(TARGET).asm

flash: $(TARGET).hex
	$(AVRDUDE) -c $(AVRWRITER) -p $(DEVICE) -b $(AVRDUDEBAUDRATE) -e -U flash:w:$<

# fuse:
# 	$(AVRDUDE) -c $(AVRWRITER) -p $(DEVICE) -b $(AVRDUDEBAUDRATE) -U lfuse:w:0x22:m

clean:
	rm -f *.obj *.eep.hex

distclean: clean
	rm -f $(TARGET).hex musicdata.asm tonedata.asm

musicdata.asm: $(MUSICDIR)/$(MUSIC).mml bin/mmlc.pl
	perl bin/mmlc.pl -f $(F_CPU) $(MUSICDIR)/$(MUSIC).mml > $@

tonedata.asm: bin/tone.pl
	perl bin/tone.pl -f $(F_CPU) > $@

psgplay.hex: psgplay.asm psgplay-commands.asm musicdata.asm tonedata.asm

.asm.hex:
	$(AS) $(ASFLAGS) $<
