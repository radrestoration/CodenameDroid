Codename Droid - C64 port (work in progress)
============================================

Run:  ./run.sh          (VICE, PAL)      ./run.sh ntsc      ./run.sh d64
      or load droid.prg / droid.d64 yourself: LOAD"DROID",8,1 then RUN (the PRG autostarts with SYS 34816)

It starts with the instruction pages (SPACE for each, RUN/STOP skips them), the logo, the scrolling artwork (any key
skips a picture), and the credits (SPACE or fire to start; V shows the controls).

Controls
  Z / X               walk left / right
  ;  /                up (climb, lift, stand up) / down (kneel, crawl, descend)
  RETURN              jump (hold Z or X for a sideways jump)
  =                   fire the blaster
  A / J               wrist terminal / jet pack screen
  D / O               drop a mine / leave the jet pack
  P / DEL             pause / resume
  CTRL                lose a life          RUN/STOP   give up
  F1 / F3             sound off / on
  Joystick port 2     left, right, up, down; fire = jump (with left or right: a sideways jump)
  On the wrist terminal: S and B charge the suit and the blaster, M shows the map, SPACE leaves.

The game is Codename Droid by Martin Edmondson and Nick Chamberlain (Superior Software, 1987).
