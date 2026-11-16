# Locked In Reader

A macOS app that locks your Mac to a single PDF until a timer runs out.

## How it works

1. Choose a PDF, a duration, and an emergency passphrase.
2. Press **Lock in**. The app covers every display and switches on kiosk mode:
   Dock and menu bar hidden, Cmd+Tab, Cmd+H, Cmd+Opt+Esc (force quit) and
   logout disabled. Cmd+Q / Cmd+W are ignored. The Mac won't idle-sleep.
3. Read. When the timer hits zero, everything unlocks and you get a summary.

If the app is killed or relaunched mid-session it drops straight back into the
lock with the remaining time.

## Emergency exit

Press **⌃⌥⌘U** during a session and enter your passphrase. Wrong guesses are
rate-limited. The passphrase is stored only as a salted hash, so it cannot be
recovered. The power button (hard shutdown) always works too.

## Build and run

```sh
swift run                  # run from the terminal (debug)
./scripts/build_app.sh     # produces build/LockedInReader.app
```

Try a short 1-minute session first to confirm the lock and the emergency exit
behave on your machine.

## Layout

```
Sources/LockedInReader/
  App/      entry point, AppDelegate (phase switching, menu, shortcuts)
  Models/   AppModel (state + timer), SessionStore (persistence, passphrase hash)
  Lock/     LockController (kiosk options, cover windows, watchdog, sleep assertion)
  Views/    SetupView, ReaderView (+ unlock prompt), PDFReaderView, DoneView
scripts/    build_app.sh
samples/    local test PDFs (gitignored)
```

## Known limits

- Holding the power button, or a hard crash of macOS, can't be prevented.
- Cmd+Ctrl+Q (lock screen) isn't blockable; the timer keeps running regardless.
