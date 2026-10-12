# Mac transcript completion

- A confirmed paste dismisses the floating recorder immediately.
- An unconfirmed but readable editor gets up to five additional seconds of
  observation after clipboard restoration. An exact insertion acknowledgement
  dismisses the fallback. This observation never repeats the paste or changes
  the clipboard, and stops on focus change, secure input or cancellation.
- By default a real failure or unreadable target keeps the manual-copy fallback. Do not
  treat a dispatched keyboard event as proof of successful insertion.
- Mac Settings > Show Copy dialog can be switched off. Failed, blocked or
  unconfirmed insertions then copy the transcript to the clipboard and dismiss
  the recorder, without presenting a transcript/copy dialog or repeating a paste.
  Confirmed pastes still restore the original clipboard. Existing settings
  retain the dialog-enabled default; iOS behavior is unchanged.
  The persisted setting is `showPasteDialog` (`true` by default).
- Silent fallback does not overwrite a newer clipboard copy made during or
  after the insertion attempt. If copying is unavailable, no dialog appears;
  the menu-bar status directs the user to the transcript saved in history.
- The menu has Paste Last Transcript and the ten newest Recent Transcripts.
- Menu actions retain the original application's focused editable field and
  wait for menu tracking to end. They cannot paste into a newly focused field.
- History remains saved before insertion. Successful-paste clipboard restoration,
  permissions, secure-field safeguards and iOS behavior are unchanged.

Regression tests cover delayed acknowledgement, clipboard restoration, no
duplicate paste, focus/security changes, menu history freshness and menu replay.
Physical acceptance in the reported editor remains a separate check.
