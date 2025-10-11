init:
	ld de,currentfolder
	OS_GETPATH
	ld hl,(currentfolder+2)
	ld a,l
	xor '/'
	or h
	jr nz,$+5
	ld (currentfolder+2),a
	
	OS_SETSYSDRV

        call loadsettings
	call detectcpuspeed
	call detectmoonsound
	call detecttfm
	call detectopm
	call detectopna
	call loadplayers
	jp nz,printerrorandexit
        ret

loadsettings
	ld de,settingsfilename
	call openstream_file
	or a
	ld de,browserpanel
	jp z,.iniFound

        ld hl,defaultGpIni
        ld bc,defaultGpIniEnd-defaultGpIni
        ldir
                
        LD DE,settingsfilename
        OS_CREATEHANDLE
        OR A
        jp NZ,.settingscreateerror
        ld a,b
        ld (filehandle),a

        ld hl,defaultGpIniEnd-defaultGpIni ;size
        ld de,defaultGpIni ;addr
;savestream_file
;de=buf
;hl=size
        ld a,(filehandle)
        ld b,a
        OS_WRITEHANDLE         ;hl=actual size

        or a
        jp nz,.settingswriteerror
	call closestream_file
        ld hl,settingswritemessage
        call print_hl
        jr .parseSettings

.iniFound
	ld hl,0x4000
	call readstream_file
	ld de,browserpanel
	add hl,de
	ld (hl),0
	call closestream_file
.parseSettings
	ld de,browserpanel
.parseloop
	ld bc,'='*256
	call findnextchar
	or a
	ret z
	cp b
	jr nz,.parseloop
	ld b,settingsvarcount
	ld hl,settingsvars
.varsearchloop
	ld a,(hl)
	inc hl
	cp c
	jr z,.foundvar
	inc hl
	inc hl
	djnz .varsearchloop
	jr .nextvar
.foundvar
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ld (hl),e
	inc hl
	ld (hl),d
.nextvar
	ld b,0
	call findnextchar
	or a
	jr nz,.parseloop
	ret
.settingscreateerror
        ld hl,settingscreateerror
        jr .swc
.settingswriteerror
        ld hl,settingswriteerror
.swc
        call print_hl
        jp .parseSettings


findnextchar
;de = ptr
;b = character to search
;c = LRC
;output: de = ptr past character, c = updated LRC
	ld a,(de)
	inc de
	or a
	ret z
	cp "\n"
	ret z
	cp b
	ret z
	xor c
	ld c,a
	jr findnextchar



detectcpuspeed
	ld hl,detectingcpustr
	call print_hl
	call swapinterrupthandler ;avoid OS while benchmarking
	halt
	ld hl,0
	ld e,0
	xor a
	ld (.spincount),a
	ld a,33
	halt
;--> 42 t-states loop start
.loop	inc e
	jp nz,$+4
	inc hl
	nop
.spincount=$+1
	ld bc,0
	cp c
	jp nc,.loop
;<-- loop end
	push de
	push hl
	call swapinterrupthandler ;restore OS handler
	pop hl
	pop de
;hl = hle / 32
	sla e : adc hl,hl
	sla e : adc hl,hl
	sla e : adc hl,hl
	ld (gpsettings.framelength),hl
	ex de,hl
	ld hl,-MIN_FRAME_LENGTH_FPGA
	add hl,de
	ld hl,cpufpgastr
	jp c,print_hl
	ld hl,-MIN_FRAME_LENGTH_ZXEVO
	add hl,de
	ld hl,cpuevostr
	jp c,print_hl
	ld hl,cpuatmstr
	jp print_hl

swapinterrupthandler
	di
	ld hl,.store
	ld de,0x38
	ld b,3
.loop	ld a,(de)
	ld c,(hl)
	ld (hl),a
	ld a,c
	ld (de),a
	inc hl
	inc de
	djnz .loop
	ei
	ret
.store	jp lightweightinterrupthandler

lightweightinterrupthandler
	push af
	ld a,(detectcpuspeed.spincount)
	inc a
	ld (detectcpuspeed.spincount),a
	pop af
	ei
	ret



isbomgemoon
;output: zf=0 is BomgeMoon flag is set
	ld hl,(bomgemoonsettings)
	ld a,l
	or h
	ret z
	ld a,(hl)
	cp '0'
	ret

detectmoonsound
	ld hl,detectingmoonsoundstr
	call print_hl
	call ismoonsoundpresent
	ld hl,notfoundstr
	jp nz,print_hl
	call opl4init
	call isbomgemoon
	jr z,.detectwaveports
	ld hl,devicebomgemoon
	ld (devicelist.moonsoundstraddr),hl
	ld a,1
	ld (gpsettings.moonsoundstatus),a
	ld hl,bomgemoonstr
	jp print_hl
.detectwaveports
	ld bc,9
	ld d,0
	ld hl,0x1200
	ld ix,browserpanel
	call opl4readmemory
	ld b,9
	ld de,rom001200
	ld hl,gpsettings.moonsoundstatus
.cmploop
	ld a,(de)
	cp (ix)
	jr nz,.waveportsfailed
	inc de
	inc ix
	djnz .cmploop
	ld (hl),2
	ld hl,foundstr
	jp print_hl
.waveportsfailed
	ld (hl),1
	ld hl,firmwareerrorstr
	call print_hl
	ld hl,pressanykeystr
	call print_hl
	YIELDGETKEYLOOP
	ret

detecttfm
	ld hl,detectingtfmstr
	call print_hl
	call istfmpresent
	ld hl,notfoundstr
	jp nz,print_hl
	ld a,1
	ld (gpsettings.tfmstatus),a
	ld hl,foundstr
	jp print_hl

trywritingopm
	dec a
	jr nz,$-1
	ld bc,OPM0_REG
	out (c),e
	ld bc,OPM1_REG
	out (c),e
	dec a
	jr nz,$-1
	ld bc,OPM0_DAT
	out (c),d
	ld bc,OPM1_DAT
	out (c),d
	ret

detectopm
	ld hl,detectingopmstr
	call print_hl
;check for non-zero as an early exit condition
	ld bc,OPM0_DAT
	in a,(c)
	or a
	ld hl,notfoundstr
	jp nz,print_hl
;start timer
	ld de,0xff12
	call trywritingopm
	ld de,0x2a14
	call trywritingopm
;wait for the timer to finish
	YIELD
	YIELD
;check the timer flags
	ld bc,OPM0_DAT
	in a,(c)
	cp 2
	ld hl,notfoundstr
	jp nz,print_hl
	ld bc,OPM1_DAT
	in a,(c)
	cp 2
	ld hl,founddualchipstr
	jr z,.hasdualopm
	call opmdisablechip1
	ld hl,foundstr
	ld a,1
.hasdualopm
	ld (gpsettings.opmstatus),a
	call print_hl
	jp opmstoptimers

trywritingopna1
	dec a
	jr nz,$-1
	ld bc,OPNA1_REG
	out (c),e
	dec a
	jr nz,$-1
	ld bc,OPNA1_DAT
	out (c),d
	ret

detectopna
	ld hl,detectingopnastr
	call print_hl
;check for non-zero as an early exit condition
	ld bc,OPNA1_REG
	in a,(c)
	or a
	ld hl,notfoundstr
	jp nz,print_hl
	ld de,0xff26
	call trywritingopna1
	ld de,0x2a27
	call trywritingopna1
;wait for the timer to finish
	YIELD
	YIELD
;check the timer flags
	ld bc,OPNA1_REG
	in a,(c)
	cp 2
	ld hl,notfoundstr
;	jp nz,print_hl
	ld a,1
	ld (gpsettings.opnastatus),a
	ld de,0x3027
	call trywritingopna1
	ld de,0x0027
	call trywritingopna1
	ld hl,foundstr
	jp print_hl

;=====================================
trywritingmoonsoundfm1
	djnz $
	ld a,e
	out (MOON_REG1),a
	djnz $
	ld a,d
	out (MOON_DAT1),a
	ret

ismoonsoundpresent
;out: zf=1 if Moonsound is present, zf=0 if not
	switch_to_pcm_ports_c2_c3
;check for 255 as an early exit condition
	in a,(MOON_STAT)
	add a,1
	sbc a,a
	ret nz
;read the status second time, now expect all bits clear
	in a,(MOON_STAT)
	or a
	ret nz
;start timer
	ld de,0xff03
	call trywritingmoonsoundfm1
	ld de,0x4204
	call trywritingmoonsoundfm1
	ld d,0x80
	call trywritingmoonsoundfm1
;wait for the timer to finish
	YIELD
	YIELD
;check the timer flags
	in a,(MOON_STAT)
	cp 0xa0
	ret nz
;there must be MoonSound in this system
	call opl4stoptimers
	xor a
	ret

trywritingtfm1
	dec a
	jr nz,$-1
	ld bc,OPN_REG
	out (c),e
	dec a
	jr nz,$-1
	ld bc,OPN_DAT
	out (c),d
	ret

istfmpresent
;check for non-zero as an early exit condition
	ld bc,OPN_REG
	ld a,%11111100
	out (c),a
	in a,(c)
	or a
	ret nz
;start timer
	ld de,0xff26
	call trywritingtfm1
	ld de,0x2a27
	call trywritingtfm1
;wait for the timer to finish
	YIELD
	YIELD
;check the timer flags
	ld bc,OPN_REG
	in a,(c)
	cp 2
	ret nz
;there must be TFM in this system
	ld de,0x3027
	call trywritingtfm1
	ld de,0x0027
	call trywritingtfm1
	xor a
	ret

;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
plr_vgm         db "gp/vgm.plr",0
plr_mp3         db "gp/mp3.plr",0
plr_pt3         db "gp/pt3.plr",0
plr_mwm         db "gp/mwm.plr",0
plr_mm          db "gp/moonmod.plr",0
plr_oplmid      db "gp/opl4mid.plr",0


playerslist:
        dw plr_mm,      gpsettings.usemoonmod
        dw plr_mwm,     gpsettings.usemwm
        dw plr_mp3,     gpsettings.usemp3
        dw plr_pt3,     gpsettings.usept3
        dw plr_vgm,     gpsettings.usevgm
        dw 0
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
loadplayers:

	xor a
	ld (playercount),a
        ld hl,playerslist
.loop1
        ld c,(hl) : inc hl
        ld b,(hl) : inc hl  ;bc = player name
        ld a,b
        or c
        jr z,.breakLoop1
        ld e,(hl) : inc hl
        ld d,(hl) : inc hl ;de- player variable
        push hl

        ex de,hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        call loadplayer
        pop hl                
        jr .loop1
.breakLoop1
	ld a,(playercount)
	dec a
	ld hl,noplayersloadedstr
	ret m
	xor a
	ret

loadplayer:
        ;bc - filename
        ;de - settings variable addr
        ld (.filename),bc      

        ld a,d
        or e
	ld a,'1' ;default for Use<Player> variable is 1
	jr z,$+3
	ld a,(de)
	cp '0'
	jp z,.skipplr

	OS_NEWPAGE
	or a
	ret nz
	ld a,e
	ld (.playerpage),a
        SETPG4000

.filename=$+1
        ld de,0
        call openstream_file
        or a
        jp nz,.noplrfound
	ld de,0x4000
	ld hl,0
	call readstream_file
        call closestream_file


	ld hl,initializing1str
	call print_hl
	ld hl,(PLAYERNAMESTRADDR)
	call print_hl
	ld hl,initializing2str
	call print_hl
	ld hl,gpsettings
	ld ix,gpsettings
	ld a,(.playerpage)
	call playerinit
	push af
	call print_hl
	pop af
	jr nz,.cleanup
	ld hl,playercount
	ld e,(hl)
	inc (hl)
	ld d,0
	ld hl,playerpages
	add hl,de
.playerpage=$+1
	ld (hl),0
	ret
.cleanup
	ld a,(.playerpage)
	ld e,a
	OS_DELPAGE
	ret

.noplrfound:
        ld hl,failedtoloadstr
        call print_hl
        ld hl,(.filename)
        call print_hl
        ld hl,crstr
        jp print_hl        

.skipplr:
        ld hl,filestr
        call print_hl
        ld hl,(.filename)
        call print_hl
        ld hl,isdisabledstr
        call print_hl
        ld hl,crstr
        jp print_hl  

defaultGpIni:
        incbin "gp.ini"
defaultGpIniEnd: