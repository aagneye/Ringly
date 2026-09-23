/**
 * Tunable thresholds gathered in one place.
 *
 * Pulled out of the modules that use them so a demo-day adjustment ("make drift
 * trigger sooner so the pipeline page has something to show") is a one-line
 * change instead of a hunt through five files.
 */

/** Longest a voice memo is allowed to run, enforced client-side by the recorder. */
export const MAX_RECORDING_SECONDS = 120;

/** Largest audio upload accepted by /api/notes, in bytes. */
export const MAX_AUDIO_UPLOAD_BYTES = 10 * 1024 * 1024;

/** How many deals the nightly review will consider acting on before capping. */
export const REVIEW_CANDIDATE_LIMIT = 8;

/** How many actions the nightly review may take in one run, enforced by the prompt. */
export const REVIEW_ACTION_CAP = 3;

/** How many previous transcripts feed the email drafter and the pre-call brief. */
export const HISTORY_WINDOW = 3;

/** Default meeting length when a memo does not state one. */
export const DEFAULT_MEETING_MINUTES = 30;
