# 29 — Sound sourcing: birdsong, forest and café

**What to build:** source material for the three sounds that synthesis does badly (birdsong as an end sound, forest and café as ambient beds). PRD v2.2 §5.4 and §8.1.1, step 2.

The rule: **public-domain (CC0) recordings only**, freely downloadable without an account. No licence that requires attribution, so the app needs no credits screen. Where no good recording qualifies, the sound is synthesised instead.

**Blocked by:** nothing.

**Status:** done. All three come from recordings; none needs synthesis.

- [x] For each of the three, either a CC0 recording downloaded into a staging folder **outside `assets/`**, or a written decision to synthesise it
- [x] Each recording's provenance recorded here: source URL, author, licence as stated on the source page, and the date it was checked. A file whose licence cannot be confirmed as CC0 or public domain is not used
- [x] Candidates suit a loop or a one-shot: beds have no memorable events (no distinct voices, no single loud bird call, no clatter); the birdsong one-shot is a clean, short phrase
- [x] Downloaded files are treated as untrusted data: each in its own empty folder, never executed, only read by the processing scripts in ticket 37

## Notes

- Possible sources include Wikimedia Commons (check each file's licence individually; much of it is CC-BY-SA, which does **not** qualify) and other CC0 libraries. Freesound needs an account to download, so it is out.
- Producing the final files (trimming, loop points, FLAC conversion, normalising) is ticket 37, not this one.

## What was chosen

Searched Wikimedia Commons, reading each file's licence from its own metadata
(`LicenseShortName`, `UsageTerms`, `AttributionRequired`) through the Commons API on
2026-10-10. Every file kept is **CC0 or public domain with `AttributionRequired: false`**.

| Sound | File | Licence | Author | Length | Why |
|---|---|---|---|---|---|
| **Café** (bed) | [Cafe ambiance.ogg](https://commons.wikimedia.org/wiki/File:Cafe_ambiance.ogg) | CC0 | Marble Toast, own work, 2024-07-07 | 20:00, 44.1 kHz stereo Vorbis | A steady murmur below ~2.5 kHz, uniform for twenty minutes. The only events are occasional clinks, so a calm 20 s window is easy to find |
| **Forest** (bed) | [20090610 0 ambience.ogg](https://commons.wikimedia.org/wiki/File:20090610_0_ambience.ogg) | Public domain (pdsounds.org #707) | nille, 2009-06-10 | 2:03, 44.1 kHz stereo Vorbis | Wind, insects and high birdsong. **Cut the loop from the first ~45 s.** After that a pulsing call around 2 kHz starts (the file is tagged crow/raven), which would be a memorable event in a loop |
| **Birdsong** (end sound) | [Turdus merula 2.ogg](https://commons.wikimedia.org/wiki/File:Turdus_merula_2.ogg) | Public domain | Oona Räisänen (Mysid), own recording, 2007-05-21 | 0:25, 44.1 kHz stereo Vorbis | A blackbird in a Finnish forest: four clean phrases about 2 s each, low noise floor, silence between. One phrase (around 13.5–16 s) is a natural 3 s one-shot |

**Rejected:** [Robin's song ZS V78-0033.wav](https://commons.wikimedia.org/wiki/File:Robin%27s_song_ZS_V78-0033.wav)
(CC0, National Library of Sweden phonograph archive). It is what PRD §5.4 asked for, a
robin, but its spectrogram shows phonograph hiss across the whole band, and most energy
below 3 kHz in harmonic stacks that look like a voice rather than a robin. The forest
tracks "Forest track 1–4" (public domain) were also rejected: they are footsteps on a
path. So the birdsong end sound is a **blackbird, not a robin**; PRD v2.2 §5.4 is updated
to match.

### Checksums of the originals

The downloads lived in a temporary scratch folder. Ticket 37 fetches them again from the
URLs above and must check these before using them:

```
6360791fdcee1f64638f0fc9abd6d2c7a1aa75fd3d2b80033170a02d025099dc  Cafe_ambiance.ogg
43848c3eda5f42829f1033112c2a91ba3e5c91b79a0532fda264c9f59856d431  20090610_0_ambience.ogg
2e713300a07d50b9cad26bb0f7b5d5bdce148ab062b56922ee3dd95fab54ec9f  Turdus_merula_2.ogg
```

### How they were judged without ears

No one listened. Each file was judged from a full-length spectrogram
(`ffmpeg … showspectrumpic`): birdsong shows as sharp sweeping traces between 2 and 8 kHz,
hiss as a flat band, voices as stacked harmonics below 3 kHz, and clinks or calls as
bright vertical lines. Ticket 37's owner listening pass is where this is checked by ear.

**Tools available here:** `ffmpeg` and `ffprobe` are installed (`/usr/bin`), which covers
decoding, trimming, loudness and FLAC encoding for ticket 37.

**Verification gap:** nobody has listened to these. Ticket 37 asks the owner to.
