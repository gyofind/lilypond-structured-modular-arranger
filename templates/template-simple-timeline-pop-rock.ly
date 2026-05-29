\version "2.25.14"
\language "deutsch"
\include "predefined-guitar-fretboards.ly"

% =====================================================================
% 0. CONFIGURATION & GLOBALS
% =====================================================================

\header {
  title = "Arrangement Master Template"
  composer = "Composer Name"
  arranger = "Arranger Name"
  copyright = "© 2026 M2B"
  tagline = "Engraved 2026 by M2B"
}

\layout {
  \context {
    \Voice
    \consists "Melody_engraver"
    \override Stem.neutral-direction = #'()
  }
  \context {
    \Staff
    \compressEmptyMeasures
    \RemoveAllEmptyStaves
  }
  \context {
    \TabStaff
    \compressEmptyMeasures
    \RemoveAllEmptyStaves  % Ensures empty tablature tracks hide completely alongside standard staves
  }
  \context {
    \DrumStaff
    \compressEmptyMeasures
    \RemoveAllEmptyStaves  % Ensures empty drum tracks hide completely when resting
  }
}

global = {
  \key c \major
  \time 4/4
}

globalChord = {
  \germanChords
}

globalLyrics = {
  \override LyricText.font-shape = #'italic
  \override LyricText.font-size = #'-1
}

% =====================================================================
% 1. SEGMENTS AND TARGET LENGTHS (THE MASTER ARRANGEMENT MAP)
% =====================================================================
% Single source of truth for durations. 
% NOTE: Inside Scheme #(), comments must use semicolons (;)

masterArrangementMap = #(list
  (cons "Intro"      #{ s1*1 #})
  (cons "VerseMain"  #{ s1*3 #})
  (cons "VerseEndA"  #{ s1*1 #})   ; Example: Volta 1 alternative branch
  (cons "VerseEndB"  #{ s1*1 #})   ; Example: Volta 2 alternative branch
  (cons "Chorus"     #{ s1*2 #})
  (cons "Outro"      #{ s1*4 #})
)

% =====================================================================
% 2. AUTOMATIC LENGTH VARIABLE CREATION WITH METADATA TAGS
% =====================================================================
% DO NOT MODIFY. Automates length assignments wrapped in native tags.

#(for-each
  (lambda (pair)
    (let* ((seg-name (car pair))
           (len-music (ly:music-deep-copy (cdr pair)))
           (var-symbol (string->symbol (string-append "Length_" seg-name)))
           (tag-sym (string->symbol (string-append "Segment_" seg-name))))
      
      (ly:parser-define! var-symbol #{ \tag #tag-sym { #len-music } #})))
  masterArrangementMap)

% =====================================================================
% 3. THE TIMELINE (Manually Editable Roadmap)
% =====================================================================

timeline = {
  \global
  \mark \default                  % Rehearsal Mark A (Bar 1)
  \Length_Intro
  
  \sectionLabel "Verse"           % Textual Section Mark (Bar 2)
  \repeat volta 2 {
    <<
      \Length_VerseMain           % Unified 3-bar block (Bars 2, 3, 4)
      {
        s1                        % Bar 2
        \mark \default            % Rehearsal Mark B (Bar 3)
        s1                        % Bar 3
        \mark \default            % Rehearsal Mark C (Bar 4)
        s1                        % Bar 4
      }
    >>
  }
  \alternative {
    \volta 1 { \Length_VerseEndA } % Bar 5
    \volta 2 { \Length_VerseEndB } % Bar 6
  }
  
  \bar "||"
  \sectionLabel "Chorus"          % Textual Section Mark (Bar 7)
  \Length_Chorus                  % Bars 7-8
  
  \sectionLabel "Outro"           % Textual Section Mark (Bar 9)
  \Length_Outro                   % Bars 9-12
  \bar "|."
}

% =====================================================================
% 4. RAW TRANSCRIPTION CHUNKS
% =====================================================================

% ---------------------------------------------------------------------
% --- MELODY & VOCALS ---
% ---------------------------------------------------------------------
Intro_melody      = \relative c' { R1 }
VerseMain_melody  = \relative c' { c4 d e f | g a b c | R1 }
VerseEndA_melody  = \relative c'' { g2 e }
VerseEndB_melody  = \relative c'' { g2 c }
Chorus_melody     = \relative c'' { g4 g f f | e e d2 }
Outro_melody      = \relative c'' { c1 ~ | c1 | R1*2 }

Intro_melodyDynamics     = { s1 }
VerseMain_melodyDynamics = { s4\p s4\< s4 s4\! | s1 | s1 }
VerseEndA_melodyDynamics = { s1 }
VerseEndB_melodyDynamics = { s1 }
Chorus_melodyDynamics    = { s1\f | s1 }
Outro_melodyDynamics     = { s1\dim | s1 | s1 | s1\p }

VerseMain_lyricsOne  = \lyricmode { \globalLyrics This is the first verse lines of text }
VerseEndA_lyricsOne  = \lyricmode { \globalLyrics end one }
VerseEndB_lyricsOne  = \lyricmode { \globalLyrics end two }
Chorus_lyricsOne     = \lyricmode { \globalLyrics Here comes the real cho -- rus line }
Outro_lyricsOne      = \lyricmode { \globalLyrics Bye __ }

VerseMain_lyricsTwo  = \lyricmode { \globalLyrics This is a se -- cond verse op -- option }

% ---------------------------------------------------------------------
% --- PIANO ---
% ---------------------------------------------------------------------
Intro_pianoRight      = \relative c' { <c e g>1 }
VerseMain_pianoRight  = \relative c' { R1 } 
VerseEndA_pianoRight  = \relative c' { R1 }
VerseEndB_pianoRight  = \relative c' { R1 }
Chorus_pianoRight     = \relative c' { R1*2 }
Outro_pianoRight      = \relative c' { R1*4 }

Intro_pianoLeft       = \relative c { c1 }
VerseMain_pianoLeft   = \relative c { R1*2 }
VerseEndA_pianoLeft   = \relative c { R1 }
VerseEndB_pianoLeft   = \relative c { R1 }
Chorus_pianoLeft      = \relative c { R1*2 }
Outro_pianoLeft       = \relative c { R1*4 }

Intro_pianoDynamics      = { s1 }
VerseMain_pianoDynamics  = { s1*3 }
VerseEndA_pianoDynamics  = { s1 }
VerseEndB_pianoDynamics  = { s1 }
Chorus_pianoDynamics     = { s1*2 }
Outro_pianoDynamics      = { s1*4 }

% ---------------------------------------------------------------------
% --- GUITAR ---
% ---------------------------------------------------------------------
Intro_guitar      = \relative c' { c4 e g e }
VerseMain_guitar  = \relative c' { R1*3 }
VerseEndA_guitar  = \relative c' { R1 }
VerseEndB_guitar  = \relative c' { R1 }
Chorus_guitar     = \relative c' { R1*2 }
Outro_guitar      = \relative c' { R1*4 }

Intro_guitarDynamics     = { s1 }
VerseMain_guitarDynamics = { s1*3 }
VerseEndA_guitarDynamics = { s1 }
VerseEndB_guitarDynamics = { s1 }
Chorus_guitarDynamics    = { s1*2 }
Outro_guitarDynamics     = { s1*4 }

% ---------------------------------------------------------------------
% --- DRUMS ---
% ---------------------------------------------------------------------
Intro_drums      = \drummode { R1 }
VerseMain_drums  = \drummode { hh4 hh hh hh | hh hh hh hh | bd4 sn bd sn }
VerseEndA_drums  = \drummode { bd4 sn bd sn }
VerseEndB_drums  = \drummode { bd4 sn bd cymc4 }
Chorus_drums     = \drummode { cymr4 hh cymr hh | cymr hh cymr hh }
Outro_drums      = \drummode { hh4 hh hh hh | hh hh hh hh | R1*2 }

% ---------------------------------------------------------------------
% --- CHORDS ---
% ---------------------------------------------------------------------
Intro_chords      = \chordmode { \globalChord c1 }
VerseMain_chords  = \chordmode { \globalChord c1*3 }
VerseEndA_chords  = \chordmode { \globalChord g1 }
VerseEndB_chords  = \chordmode { \globalChord c1 }
Chorus_chords     = \chordmode { \globalChord f1 | c1 }
Outro_chords      = \chordmode { \globalChord c1*4 }


% =====================================================================
% 5. THE STRUCTURAL BLUEPRINT ENGINES
% =====================================================================
% DO NOT MODIFY. Traverses structural lines and filters rendering side-effects.

% --- Engine A: Structural Note & Polyphonic Layering ---
buildStructuredContent =
#(define-music-function (part structure) (string? ly:music?)
   (letrec ((get-seg-name
             (lambda (tags)
               (if (null? tags)
                   #f
                   (let ((str (symbol->string (car tags))))
                     (if (and (>= (string-length str) 8)
                              (string=? (substring str 0 8) "Segment_"))
                         (substring str 8 (string-length str))
                         (get-seg-name (cdr tags)))))))
            
            (transform
             (lambda (mus)
               (let* ((mname (ly:music-property mus 'name))
                      (tags (ly:music-property mus 'tags '()))
                      (seg-name (get-seg-name (if (list? tags) tags '()))))
                 
                 (if (and (member mname '(ApplyContext BarCheck LineBreakEvent PageBreakEvent MarkEvent))
                          (not (string=? part "timeline")))
                     #{ #}
                     
                     (if (string? seg-name)
                         (let* ((len-sym (string->symbol (string-append "Length_" seg-name)))
                                (len-music (ly:parser-lookup len-sym))
                                (raw-sym (string->symbol (string-append seg-name "_" part)))
                                (raw-music (ly:parser-lookup raw-sym)))
                           
                           (if (ly:music? raw-music)
                               #{ << #len-music #raw-music >> #}
                               #{ << #len-music >> #}))
                         
                         (let ((copy (ly:music-deep-copy mus)))
                           (let ((elt (ly:music-property copy 'element)))
                             (if (ly:music? elt)
                                 (ly:music-set-property! copy 'element (transform elt))))
                           (let ((elts (ly:music-property copy 'elements)))
                             (if (pair? elts)
                                 (ly:music-set-property! copy 'elements (map transform elts))))
                           copy)))))))
     
     (transform structure)))

% --- Engine B: Linear Lyric Stream Flattening ---
% Safeguards \lyricsto note-matching alignment by completely bypassing timeline wrappers
buildSequentialLyrics =
#(define-music-function (part) (string?)
   (letrec ((parse-map
             (lambda (map-list)
               (if (null? map-list)
                   '()
                   (let* ((seg-name (car (car map-list)))
                          (raw-sym (string->symbol (string-append seg-name "_" part)))
                          (raw-music (ly:parser-lookup raw-sym)))
                     (cons (if (ly:music? raw-music)
                               (ly:music-deep-copy raw-music)
                               #{ #})
                           (parse-map (cdr map-list))))))))
     (make-sequential-music (parse-map masterArrangementMap))))

% =====================================================================
% 6. ASSEMBLY (Dynamic Generation - Single Source of Truth for Tracks)
% =====================================================================

chordsNames     = \buildStructuredContent "chords" \timeline

melody          = \buildStructuredContent "melody" \timeline
melodyDynamics  = \buildStructuredContent "melodyDynamics" \timeline

lyricsStanzaA   = \buildSequentialLyrics "lyricsOne"
lyricsStanzaB   = \buildSequentialLyrics "lyricsTwo"

pianoRight      = \buildStructuredContent "pianoRight" \timeline
pianoLeft       = \buildStructuredContent "pianoLeft" \timeline
pianoDynamics   = \buildStructuredContent "pianoDynamics" \timeline

guitar          = \buildStructuredContent "guitar" \timeline
guitarDynamics  = \buildStructuredContent "guitarDynamics" \timeline

drumsTrack      = \buildStructuredContent "drums" \timeline

% =====================================================================
% 7. PARTS DEFINITION
% =====================================================================

leadSheetPart = <<
  \new ChordNames \chordsNames
  \new Staff \with { instrumentName = "Melody" } <<
    \global
    \new Voice = "vocalVoice" { \melody }
    \new Dynamics { \melodyDynamics }
  >>
  \new Lyrics \lyricsto "vocalVoice" \lyricsStanzaA
  \new Lyrics \lyricsto "vocalVoice" \lyricsStanzaB
>>

pianoPart = \new PianoStaff \with { 
  instrumentName = "Piano" 
} <<
  \new Staff = "up" { \global \pianoRight }
  \new Dynamics { \pianoDynamics }
  \new Staff = "down" { \global \clef bass \pianoLeft }
>>

guitarPart = <<
  \new Staff \with { instrumentName = "Guitar" } <<
    \global
    \new Voice { \guitar }
    \new Dynamics { \guitarDynamics }
  >>
  \new TabStaff {
    \global
    \new TabVoice { \guitar }
  }
>>

drumsPart = \new DrumStaff \with {
  instrumentName = "Drums"
  shortInstrumentName = "Dr."
} {
  \drumsTrack
}

% =====================================================================
% 8. MASTER COMBINATION BLUEPRINTS
% =====================================================================

musicFullScore = {
  <<
    \new Devnull \timeline  
    \leadSheetPart
    \pianoPart
    \guitarPart
    \drumsPart
  >>
}

musicLeadSheet = {
  <<
    \new Devnull \timeline
    \leadSheetPart
  >>
}

musicPianoVocal = {
  <<
    \new Devnull \timeline
    \leadSheetPart 
    \pianoPart
  >>
}

musicStringsAndFrets = {
  <<
    \new Devnull \timeline
    \guitarPart
  >>
}

% =====================================================================
% 9. TARGET OUTPUT SINGLE-BOOK COMPILATION (UNIFIED LAYOUT & MIDI)
% =====================================================================

\book {
  \header {
    title = "Master Project Compilation"
  }

  % --- PART 1: FULL CONDUCTOR SCORE ---
  \bookpart {
    \header { subtitle = "Conductor's Full Score" }
    \score {
      { \musicFullScore }
    }
    \score {
      \unfoldRepeats { \musicFullScore }
      \midi { \tempo 4=120 }
    }
  }

  % --- PART 2: LEAD SHEET ---
  \bookpart {
    \header { subtitle = "Lead Sheet" }
    \score {
      { \musicLeadSheet }
    }
    \score {
      \unfoldRepeats { \musicLeadSheet }
      \midi { \tempo 4=120 }
    }
  }

  % --- PART 3: PIANO & VOCAL INTERMEDIATE SCORE ---
  \bookpart {
    \header { subtitle = "Piano / Vocal Score" }
    \score {
      { \musicPianoVocal }
    }
    \score {
      \unfoldRepeats { \musicPianoVocal }
      \midi { \tempo 4=120 }
    }
  }

  % --- PART 4: FRETTED STRINGS ---
  \bookpart {
    \header { subtitle = "Guitar Performance Layout" }
    \score {
      { \musicStringsAndFrets }
    }
    \score {
      \unfoldRepeats { \musicStringsAndFrets }
      \midi { \tempo 4=120 }
    }
  }
}
