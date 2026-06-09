# lilypond-structured-modular-arranger
LiSMA - A highly structured, modular, semantic GNU LilyPond (v2.25+) framework for managing complex musical arrangements and transcriptions

## 🏛️ Architectural Core

This framework enforces a strict **Separation of Concerns** broken into distinct programmatic layers:
1. **The Master Arrangement Map:** Centralizes segment names and exact rhythmic lengths.
2. **The Timeline (Roadmap):** Houses structural items only (repeats, voltas, rehearsal marks, section labels).
3. **The Data Chunks:** Isolated, pure musical expressions (pitches, lyrics, or standalone dynamic tracks) categorized by segment name and part.
4. **The Structural Blueprints (Scheme Engines):** * **Engine A (Padding):** Automatically injects correct spacer rests if an instrument is resting or unwritten during a specific segment.
   * **Engine B (Sequential Lyrics):** Flattens vocal tracks into sequential blocks to protect `\lyricsto` from losing alignment on structural boundaries.

---

## 📁 Repository Structure

```text
├── doc/
│   └── reference/
│       └── notation.md                             # Technical notation architecture reference manual
├── templates/
│   ├── template-simple-timeline-pop-rock.ly        # Standard roadmap blueprint optimized for pop/rock forms
│   └── template-timeline-minimal-two-stanzas-lyrics.ly # Minimal layout handling multi-stanza vocal alignments
├── AI-INSTRUCTIONS.md                              # System prompt to feed LLMs for context-aware development
└── README.md                                       # Project documentation
