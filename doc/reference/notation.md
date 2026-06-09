# LiSMA (LilyPond-Structured-Modular-Arranger) Notation Reference: The Timeline-Blueprint Architecture

This technical manual documents the syntax, execution flow, and structural design patterns of the **Timeline-Blueprint Architecture** for LilyPond scores. This framework establishes an absolute separation between a composition's chronological roadmap (**Structure**) and its musical data (**Content**), utilizing GNU Guile Scheme to dynamically synthesize multi-instrument arrangements for both high-fidelity graphical print and unfolded linear MIDI playback.

---

## 1. Architectural Overview

The LiSMA architecture processes musical data through a multi-tiered compilation pipeline. Instead of binding expressions linearly, the framework passes raw musical fragments through a structural compiler that overlays them onto a centralized temporal master map. The following blueprint demonstrates an example of this structure.

```
+-----------------------------------------------------------------+
| DATA LAYER (Section 1 & Section 4)                              |
|   - masterArrangementMap (Scheme Pair List)                     |
|   - Raw Chunks ([Segment]_[Part], e.g., Verse_melody)           |
+-----------------------------------------------------------------+
                                |
                                v
+-----------------------------------------------------------------+
| AUTOMATION LOOP (Section 2)                                     |
|   - Generates \Length_[Segment] variables with metadata tags    |
+-----------------------------------------------------------------+
                                |
                                v
+-----------------------------------------------------------------+
| STRUCTURAL ROADMAP (Section 3: The Master Timeline)            |
|   - Evaluates repeat loops, alternatives, and volta logic       |
+-----------------------------------------------------------------+
                                |
                                v
+-----------------------------------------------------------------+
| SYNTHESIS ENGINE (Section 5: buildStructuredContent)            |
|   - Recursively maps Raw Chunks to Structural Lengths           |
+-----------------------------------------------------------------+
                                |
                                v
+-----------------------------------------------------------------+
| ASSEMBLY (Section 6: Tier-2 Processing & Vocal Prism)           |
|   - Resolves unified \melody into \vocalMain, \vocalAligner     |
+-----------------------------------------------------------------+
                                |
                                v
+-----------------------------------------------------------------+
| PARTS DEFINITIONS (Section 7: Context Wrapping)                 |
|   - Evaluates \new Staff, \new TabStaff, \new ChoirStaff        |
+-----------------------------------------------------------------+
                                |
                                v
+-----------------------------------------------------------------+
| MASTER BLUEPRINTS (Section 8: \music* Master Variables)         |
|   - Pairs Parts Definitions with \new Devnull \timeline         |
+-----------------------------------------------------------------+
                                |
                                v
+-----------------------------------------------------------------+
| OUTPUT EXTRACTION (Section 9: Tier-1 Processing)                |
|   - Applies \toLayout (Folded PDF) or \toMidi (Linear Playback) |
+-----------------------------------------------------------------+

```

---

## 2. Data Layer & Variable Automation

The structural core begins with an associative list defining the song's formal anatomy.

### 2.1 The Master Arrangement Map

In Section 1, the `masterArrangementMap` is an immutable list of pairs (`list` of `cons` cells) evaluated by the Guile interpreter. The key (`car`) is a string matching the structural segment name. The value (`cdr`) is a native LilyPond music block containing silent spacer rests (`s`) establishing the baseline duration of that section.

```lilypond
% =====================================================================
% 1. SEGMENTS AND TARGET LENGTHS (THE MASTER ARRANGEMENT MAP)
% =====================================================================

masterArrangementMap = #(list
  (cons "Intro"           #{ s1*2 #})
  (cons "Verse"           #{ s1*3 #})
  (cons "VerseEndAltOne"  #{ s1*1 #})   
  (cons "VerseEndAltTwo"  #{ s1*1 #})   
  (cons "Chorus"          #{ s1*2 #})
  (cons "Outro"           #{ s1*2 #})
)

```

### 2.2 Scheme Automation Loop

In Section 2, to avoid manual variable declarations, a Scheme `for-each` routine iterates over the pair list at parse time. For each element, it programmatically generates global LilyPond identifiers.

```lilypond
% =====================================================================
% 2. AUTOMATIC LENGTH VARIABLE CREATION WITH METADATA TAGS
% =====================================================================

#(for-each
  (lambda (pair)
    (let* ((seg-name (car pair))
           (len-music (ly:music-deep-copy (cdr pair)))
           (var-symbol (string->symbol (string-append "Length_" seg-name)))
           (tag-sym (string->symbol (string-append "Segment_" seg-name))))
      
      (ly:parser-define! var-symbol #{ \tag #tag-sym { #len-music } #})))
  masterArrangementMap)

```

* **`ly:music-deep-copy`**: Allocates an independent structural expression in memory to avoid reference mutation.
* **`ly:parser-define!`**: Injects a newly constructed variable directly into LilyPond's top-level scope.
* **Result**: Calling `\Length_Intro` returns a spacer expression wrapped in a semantic metadata tag (`#'Segment_Intro`).

---

## 3. The Structural Roadmap (The Timeline)

In Section 3, the `timeline` variable controls layout, operational markings, and repetition logic. It contains no pitch or lyrical information, acting purely as an abstract clock tracking structural boundaries.

```lilypond
% =====================================================================
% 3. THE TIMELINE (Manually Editable Roadmap)
% =====================================================================

timeline = {
  \global
  \tag #'typeset { \sectionLabel "Intro" }              
  \Length_Intro
  \tag #'typeset { \section }
  
  \repeat segno 2 {
    \volta 1 {
      \repeat volta 2 {
        <<
          { \Length_Verse }     
          {
            s1*2                                 
            \tag #'typeset { \mark \default }        
            s1                                    
          }
        >>
        \tag #'typeset { \codaMark \default \break }
        \alternative {
          \volta 1 { \Length_VerseEndAltOne } 
          \volta 2 { \Length_VerseEndAltTwo } 
        }
        \tag #'typeset { \section }
      }
      \tag #'typeset { \sectionLabel "Chorus" }      
      \Length_Chorus              
      \tag #'typeset { \section }
    }
    \volta 2 {
      \unfolded {
        \repeat volta 3 {
          \volta 3 {
            \Length_Verse
          }
        }
      }
      \tag #'typeset { \section }
    }
  }
  \tag #'typeset { 
    \stopStaff s1 \startStaff 
    \undo \omit Score.CodaMark
    \sectionLabel \markup { \bold "Coda" }
  }
  \Length_Outro                    
  \fine
}

```

### 3.1 Repeat Serialization Logic

Pop-rock scores often present complex structural differences between print and audio outputs. In Section 3, the timeline uses conditional routing blocks (`\volta 1` and `\volta 2`) under a global `\repeat segno` structure:

* **Visual Layer (`\volta 1`)**: Standard musical abbreviations (folded repeat brackets, alternate endings, coda jumps) are formatted using the `#'typeset` tag.
* **Audio Layer (`\volta 2`)**: A dedicated linear section executes when building MIDI files. It handles structural variants that bypass print markings.

### 3.2 The Volta Register Manipulation Hack

When linear tracks execute during the second pass (`\volta 2`), the score must occasionally source specific rhythmic components from structural variations. To force LilyPond to access multi-pass properties inside custom music macros, Section 3 uses a dummy iteration sequence:

```lilypond
\unfolded { \repeat volta 3 { \volta 3 { ... } } }

```

Wrapping the timeline segments in an unprinted, third-pass volta manually pushes LilyPond's internal repeat counter to state `3`. This allows downstream structural macros to correctly access notes assigned to late-stage loops.

---

## 4. Rhythmic Multiplexing & AST Manipulation

To handle subtle rhythmic shifts between different stanzas or layers without duplicating blocks, custom Scheme music functions manipulate LilyPond's Abstract Syntax Tree (AST).

### 4.1 The `\variant` Multiplexer

The `\variant` macro embeds two diverging musical paths inside a single execution block, creating distinct layers for typography and audio playback.

```lilypond
variant = #(define-music-function (main-mus opt-mus) (ly:music? ly:music?)
  #{
    <<
      \tag #'typeset {
        <<
          \tag #'mainTrack { \voiceOne #main-mus \oneVoice }
          \tag #'alignerTrack { #opt-mus }
          \tag #'optionalTrack { \tag #'variantTag { \asSmall #opt-mus } }
        >>
      }
      \tag #'playback {
        <<
          \tag #'mainTrack { \volta 1,3 { #main-mus } \volta 2 { #opt-mus } }
          \tag #'alignerTrack { \volta 1,3 { #main-mus } \volta 2 { #opt-mus } }
          \tag #'optionalTrack { \volta 1,3 { #main-mus } \volta 2 { #opt-mus } }
        >>
      }
    >>
  #})

```

* **Visual Layer (`#'typeset`)**: Simultaneously overlays both paths. The primary option is assigned to `\voiceOne` (stems up), while the alternate variant is shunted into a secondary channel (`#'optionalTrack`) using small cue-note properties via `\asSmall`.
* **Playback Layer (`#'playback`)**: Routes the performance linearly over time. Passes 1 and 3 output the main phrasing, while Pass 2 extracts the alternate phrasing.

### 4.2 AST Filtering via `makeSharedNotesSkips`

To display alternative cue notes cleanly without printing duplicate primary noteheads, the framework processes the expression through an AST filter.

```scheme
#(define (make-shared-skips mus)
   (letrec ((process (lambda (m)
              (let ((tags (ly:music-property m 'tags '())))
                (if (memq 'variantTag tags)
                    m
                    (begin
                      (if (ly:music? (ly:music-property m 'element))
                          (ly:music-set-property! m 'element (process (ly:music-property m 'element))))
                      (if (pair? (ly:music-property m 'elements))
                          (ly:music-set-property! m 'elements (map process (ly:music-property m 'elements))))
                      (if (memq (ly:music-property m 'name) '(NoteEvent RestEvent))
                          (make-music 'SkipEvent 'duration (ly:music-property m 'duration))
                          m)))))))
     (process (ly:music-deep-copy mus))))

```

This recursive routine walks the compilation tree. If it finds an expression marked with `variantTag`, it leaves it intact. For all other sections, it intercepts standard note-events (`NoteEvent`) and rest-events (`RestEvent`) and replaces them with silent spacer skips (`SkipEvent`), preserving precise temporal tracking while removing unwanted duplicate symbols.

---

## 5. Content Transcription Chunks

In Section 4, musical information is transcribed in atomic segments using a strict naming convention: `[SegmentName]_[Instrument]`. Chunks are written in standard LilyPond syntax, isolated from any structural repeat logic.

```lilypond
% =====================================================================
% 4. RAW TRANSCRIPTION CHUNKS
% =====================================================================

% --- CHORDS ---
Intro_chords           = \chordmode { \globalChord g1*2 }
Verse_chords           = \chordmode { \globalChord g1 c1 d1 }
VerseEndAltOne_chords  = \chordmode { \globalChord g1 }
VerseEndAltTwo_chords  = \chordmode { \globalChord e1:m }
Chorus_chords          = \chordmode { \globalChord c1 d1 }
Outro_chords           = \chordmode { \globalChord g1*2 }

% --- MELODY ---
Intro_melody          = \relative c'' { R1*2 }
Verse_melody          = \relative c'' { 
  g4 
  \variant { \fixed c' { a4 } } { \fixed c' { a8 fis8 } }
  \addHarmony { h4 c4 } { \parenthesize d4 < \parenthesize e \parenthesize a>4 }
  d2. r4 
}
VerseEndAltOne_melody = \relative c'' { g2 2 }
VerseEndAltTwo_melody = \relative c'' { h2 2 }
Chorus_melody         = \relative c'' { c4 c h h | a a g2 }
Outro_melody          = \relative c'' { g1 ~ | g1 }

% --- LYRICS ---
Intro_lyrics    = \lyricmode { \globalLyrics Let's go }
Verse_lyricsOne = \lyricmode { \globalLyrics First verse op -- tion here shared part }
Verse_lyricsTwo = \lyricmode { \globalLyrics Se -- cond verse op -- tion here shared part }
Outro_lyrics    = \lyricmode { \globalLyrics Out __ }

```

### Lyrical Event Synch Mechanics

When transcribing lyrics via `\lyricmode` in Section 4, syllables map directly to note-events rather than temporal durations.

* **The Underscore (`_`) Event**: Inside an active `\lyricsto` link, duration indicators are discarded. An underscore (`_`) registers as a single blank event, skipping exactly one note head. This allows you to easily skip intros or lead-ins without having to calculate duration values.

---

## 6. Synthesis & Assembly (Tier-2 Processing)

In Section 5, the compilation engine uses `buildStructuredContent` to recursively step through the timeline and merge structural spacer blocks with matching raw musical components.

```lilypond
% =====================================================================
% 5. THE STRUCTURAL BLUEPRINT ENGINE (Immutable)
% =====================================================================
buildStructuredContent =
#(define-music-function (part structure) (string? ly:music?)
   (letrec ((get-seg-name
             (lambda (tags)
                (if (null? tags) #f
                   (let ((str (symbol->string (car tags))))
                     (if (and (>= (string-length str) 8)
                              (string=? (substring str 0 8) "Segment_"))
                         (substring str 8 (string-length str))
                         (get-seg-name (cdr tags)))))))
            (transform
              ...
              % Recursive AST replacement tracking matches [SegmentName]_[part]
              ...
     (transform structure)))

```

### 6.1 Assembly Pipelines & The Vocal Prism Split

In Section 6, raw combined tracks are generated. Unified instrument parts match their structural identifiers directly (e.g., `melody`, `pianoRight`, `bass`). Vocal tracks are split into specialized components using tag filters to manage complex lyrics and alternate rhythms cleanly.

```lilypond
% =====================================================================
% 6. ASSEMBLY (Single Source of Truth)
% =====================================================================
chordsNames = \buildStructuredContent "chords" \timeline
melody      = \buildStructuredContent "melody" \timeline
pianoRight  = \buildStructuredContent "pianoRight" \timeline
bass        = \buildStructuredContent "bass" \timeline

% The Vocal Prism Split (Extracted from the master melody track)
vocalMain     = \removeWithTag #'alignerTrack \removeWithTag #'optionalTrack \melody
vocalAligner  = \removeWithTag #'mainTrack \removeWithTag #'optionalTrack \melody
vocalOptional = \makeSharedNotesSkips \removeWithTag #'mainTrack \removeWithTag #'alignerTrack \melody

% --- LYRICS ASSEMBLY ---
lyricsLineOne = \lyricmode {
  \Intro_lyrics
  \set stanza = "1. 3." \Verse_lyricsOne
  \Outro_lyrics
}

lyricsLineTwo = \lyricmode {
  _ _ _ _ % Explicit note events skipped over the intro block
  \set stanza = "2." \Verse_lyricsTwo
}

```

---

## 7. Parts Definition & Context Layouts

In Section 7, assembled track variables are wrapped inside explicit LilyPond structural contexts (`Staff`, `TabStaff`, `ChordNames`).

```lilypond
% =====================================================================
% 7. PARTS DEFINITION
% =====================================================================

leadSheetPart = 
\new ChoirStaff \with { \accepts NullVoice } <<
  \new ChordNames \chordsNames
  \new Staff \with { 
    instrumentName = "Melody" 
    \accepts NullVoice
  } <<
    \global
    \new Voice = "vocalVoice" { \vocalMain }
    \new Voice = "optionalVoice" { \vocalOptional }
    \new NullVoice = "aligner" { \vocalAligner }
  >>
  
  \tag #'typeset {
    \new Lyrics \lyricsto "vocalVoice" { \lyricsLineOne }
  }
  \tag #'typeset {
    \new Lyrics \with { alignAboveContext = #"Melody" } \lyricsto "aligner" { \lyricsLineTwo }
  }
  \tag #'unfolded {
    \new Lyrics \lyricsto "vocalVoice" { \lyricsUnfolded }
  }
>>

```

### 7.1 The NullVoice Tracking Mechanism

* **`NullVoice`**: Instantiates a silent structural tracking context in Section 7. It tracks note lengths and positions to align lyrics without printing any visual notation or affecting stem directions on the main staff.
* **`\accepts NullVoice`**: Explicitly modifies the parent context's policies to allow a `NullVoice` to be nested directly inside `Staff` or `ChoirStaff` containers.

### 7.2 Independent Lyric Tagging Policy

When using tags to filter lyrics based on the output format in Section 7, each lyric line must be enclosed within its own independent tag expression. Sequential encapsulation (`\tag #'typeset { \new Lyrics ... \new Lyrics ... }`) is invalid as it disrupts simultaneous stacking and lyric alignment across staves.

---

## 8. Master Combination Blueprints

In Section 8, Master Blueprints combine individual instrument parts into larger orchestration units. Every combination blueprint must overlay an invisible tracking timeline using a `Devnull` context.

```lilypond
% =====================================================================
% 8. MASTER COMBINATION BLUEPRINTS (Unified & Raw)
% =====================================================================

musicFullScore = {
  <<
    \new Devnull \timeline  
    \leadSheetPart
    \rhythmSectionPart
  >>
}

musicLeadSheet = {
  <<
    \new Devnull \timeline
    \leadSheetPart
  >>
}

```

The `Devnull` context acts as a silent reference clock running alongside the parts in Section 8. It processes the timeline's underlying structure while swallowing visual symbols, ensuring that section markers, repeat boundaries, and layout breaks apply uniformly across every active staff in the score.

---

## 9. Output Processing (Tier-1 Extraction)

At the final document compile stage in Section 9, global routing filters act as structural switches, preparing the master blueprints for print or audio output.

```lilypond
% =====================================================================
% SEMANTIC OUTPUT SWITCHES (Tier-1 Global Routing)
% =====================================================================
toLayout = #(define-music-function (mus) (ly:music?)
  #{ \removeWithTag #'unfolded \removeWithTag #'playback #mus #})

toMidi = #(define-music-function (mus) (ly:music?)
  #{ \removeWithTag #'typeset \unfoldRepeats #mus #})

```

### 9.1 Multi-Target Compilation Execution

The outputs are compiled inside a unified `\book` context in Section 9, using `\bookpart` blocks to separate layouts cleanly.

```lilypond
% =====================================================================
% 9. OUTPUT COMPILATION
% =====================================================================
\book {
  \header { title = "Arrangement Master Blueprint" }
  
  % --- TARGET 1: PRINTED ENGRAVED SYSTEM ---
  \bookpart {
    \header { subtitle = "Conductor Full Score" }
    \score {
      { \toLayout \musicFullScore }
      \layout { #(layout-set-staff-size 15) }
    }
  }

  % --- TARGET 2: STANDALONE PERFORMANCE SHEET ---
  \bookpart {
    \header { subtitle = "Lead Sheet" }
    \score {
      { \toLayout \musicLeadSheet }
      \layout { }
    }
  }
  
  % --- TARGET 3: MIDI AUDIO GENERATION ---
  \bookpart {
    \score {
      \toMidi \musicFullScore
      \midi { \tempo 4=120 }
    }
  }
}

```

* **`\toLayout`**: Executed within Section 9's visual scores to filter out the linear playback tags (`#'unfolded`, `#'playback`), compressing the timeline down to standard printed repeat bars and alternative brackets.
* **`\toMidi`**: Executed within Section 9's audio render blocks to filter out layout elements (`#'typeset`), isolate the sequential performance path, and run `\unfoldRepeats`. This flattens all loops into a continuous linear timeline, generating an accurate, high-fidelity audio mix.
