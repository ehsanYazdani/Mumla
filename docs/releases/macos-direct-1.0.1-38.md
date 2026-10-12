# Mumla for Mac 1.0.1 (38) - Silent Clipboard Fallback Beta

## New

- Mac Settings > Show Copy dialog can now be switched off. Failed, blocked or
  unverified auto-pastes then copy the transcript to the clipboard and dismiss
  the bottom recorder, without a transcript/copy dialog. Paste manually with Cmd+V.
- Successful auto-pastes still restore the original clipboard and hide the bar.
  There is no automatic retry that could duplicate text.
- A newer clipboard copy made during or after insertion is protected. If Mumla
  cannot safely copy, the transcript remains in History and the menu-bar status
  says why. Paste Last Transcript and Recent Transcripts remain available.
- Switching the setting off also copies and dismisses an already-open fallback.
  The setting is saved locally and existing users keep the dialog-enabled default.

Includes build 37's local formatting and separate summary previews, editable
style preferences, and recent-transcript menu. Apple Intelligence features need
a compatible Mac with macOS 26 and Apple Intelligence enabled and ready. Their
real Swedish output quality is still experimental; review previews before use.

## Install

Use Check for Updates in the direct Mac app, or download the notarized ZIP from
this release, quit Mumla and replace the copy in Applications. In Mac Settings,
switch off Show Copy dialog / Visa kopieringsruta to enable silent fallback.

Keep Microphone, Input Monitoring and Accessibility permissions enabled. Do not
run the direct and TestFlight copies simultaneously. Dictation supports macOS 14
or later. iOS and the sandboxed Mac TestFlight build are unchanged by this release.

## Testing

Check successful paste, failed paste, no focused field, secure input, and clipboard
restoration in your actual editor. Confirm no copy dialog appears with the setting
off and the transcript is available for manual pasting or in History. Automated
tests do not establish physical hotkey, target-app or model-quality acceptance.

Swedish dictation only. Meetings, English ASR and iCloud sync are not implemented.
