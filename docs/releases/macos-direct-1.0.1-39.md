# Mumla for Mac 1.0.1 (39) - Chromium Paste Confirmation Beta

## Fixed

- Recognize successful auto-pastes into empty Chromium/Electron rich-text
  fields that report their initial text as a newline. Previously the text
  could be inserted while Mumla still showed the copy fallback.
- Once the complete inserted text is confirmed, the bottom recorder dismisses
  and the original clipboard is restored. Unchanged fields, partial text and
  unrelated changes are not accepted as successful pastes.
- Thanks to @ehsanYazdani for
  [PR #2](https://github.com/simonbromander/Mumla/pull/2).

Includes build 38's Show Copy dialog setting: turn it off to copy blocked or
unconfirmed dictations to the clipboard without showing a copy panel. Newer
user copies are protected. There is no automatic paste retry. History, Paste
Last Transcript and Recent Transcripts remain the recovery paths.

Local formatting, summary previews and style preferences from build 37 remain
experimental. They require a compatible Mac with macOS 26 and Apple
Intelligence enabled and ready. Review generated previews before using them.

## Install

Choose Check for Updates in the direct Mac app, or download this release's
notarized ZIP, quit Mumla and replace the copy in Applications. Keep Microphone,
Input Monitoring and Accessibility permissions enabled. Do not run direct and
TestFlight copies simultaneously.

This is a direct Mac beta for macOS 14 or later, on Apple silicon and Intel.
iOS and the sandboxed Mac TestFlight build are unchanged by this release.
The app source is public under MIT; model and library licenses remain separate.

## Testing

Try an empty message field and a field with existing text in your actual
Chromium/Electron app. After a successful paste, check that the bottom bar
disappears, the text appears once and the prior clipboard is restored. Also
check blocked paste, secure input, changed focus and newer clipboard copies.

Automated verification does not establish real target-app acceptance, physical
hotkey delivery, live update installation or Swedish model quality. Swedish
dictation only; English ASR, meetings and iCloud sync are not implemented.
