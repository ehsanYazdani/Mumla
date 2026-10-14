# Mumla for Mac 1.0.1 (40) - Microphone and Reliability Beta

## New And Fixed

- Fix a crash when reopening Mumla's main window or Settings after closing
  the window. The menu-bar app keeps its window alive for reuse.
- Choose a dictation microphone in Settings or the menu bar. Mumla remembers
  the choice instead of following system input changes when connecting devices
  such as AirPods. The system-wide default microphone is not changed.
- If the remembered microphone is disconnected or cannot start, dictation
  falls back to the system default. A disconnected choice stays visible;
  reconnecting the remembered device lets Mumla use it again.
- Show a short explanation when Secure Input blocks the dictation trigger,
  instead of leaving a key press unexplained. Secure Input remains respected;
  the warning does not enable recording or read protected fields.
- Thanks to @ehsanYazdani for
  [PR #3](https://github.com/simonbromander/Mumla/pull/3),
  [PR #4](https://github.com/simonbromander/Mumla/pull/4) and
  [PR #5](https://github.com/simonbromander/Mumla/pull/5).

Includes build 39's Chromium/Electron empty-editor paste confirmation fix.
Confirmed pastes restore the previous clipboard and dismiss the recorder.
Turn off Show Copy dialog in Mac Settings for silent clipboard fallback when
paste cannot be confirmed. History and the recent-transcript menu remain
available, with no automatic paste retry.

Local formatting, summary previews and style preferences remain experimental.
They require a compatible Mac with macOS 26 and Apple Intelligence enabled
and ready. Review generated previews before using them.

## Install

Choose Check for Updates in the direct Mac app, or download this release's
notarized ZIP, quit Mumla and replace the copy in Applications. Keep Microphone,
Input Monitoring and Accessibility permissions enabled. Do not run direct and
TestFlight copies simultaneously.

This is a direct Mac beta for macOS 14 or later, on Apple silicon and Intel.
iOS and the sandboxed Mac TestFlight build are unchanged by this release.
The app source is public under MIT; model and library licenses remain separate.

## Testing

Close and reopen the main window and Settings from the menu bar. Try a pinned
microphone, a different system default, disconnection and reconnection, and
System Default mode. Verify recording level and the resulting transcript.
While Secure Input is active, confirm that a trigger press explains the block
without recording; normal dictation should resume after Secure Input ends.
Also check paste, clipboard restoration and newer copies in your actual editor.

Automated verification does not establish physical microphone routing, hotkey
delivery, target-app paste, live update installation or Swedish model quality.
Swedish dictation only; English ASR, meetings and iCloud sync are not implemented.
