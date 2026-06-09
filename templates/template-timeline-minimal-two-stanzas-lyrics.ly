\version "2.25.14"
\language "deutsch"

% =====================================================================
% 0. CONFIGURATION, GLOBALS & SEMANTIC SWITCHES
% =====================================================================

global = {
  \key g \major
  \time 4/4
}

% Semantic Output Switches (Global Routing)
toLayout = #(define-music-function (mus) (ly:music?)
  #{ \removeWithTag #'unfolded \removeWithTag #'playback #mus #})

toMidi = #(define-music-function (mus) (ly:music?)
  #{ \removeWithTag #'typeset \unfoldRepeats #mus #})

% =====================================================================
% 1. SEGMENTS AND TARGET LENGTHS (THE MASTER ARRANGEMENT MAP)
% =====================================================================

masterArrangementMap = #(list
  (cons "Intro" #{ s1 #})
  (cons "Verse" #{ s1 #})
  (cons "Outro" #{ s1 #})
)

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

% =====================================================================
% 3. THE TIMELINE (Manually Editable Roadmap)
% =====================================================================

timeline = {
  \global
  \Length_Intro
  
  \repeat volta 2 {
    \Length_Verse
  }
  
  \Length_Outro
  \fine
}

% =====================================================================
% 4. RAW TRANSCRIPTION CHUNKS
% =====================================================================

% --- CHORDS ---
Intro_chords = \chordmode { g1 }
Verse_chords = \chordmode { c1 }
Outro_chords = \chordmode { g1 }

% --- MELODY ---
Intro_melody = \relative c'' { g2 g2 }
Verse_melody = \relative c'' { c8 c h4 a g }
Outro_melody = \relative c'' { g2 g }

% --- LYRICS ---
Intro_lyrics    = \lyricmode { Let's go }
Verse_lyricsOne = \lyricmode { Stan -- za one is here }
Verse_lyricsTwo = \lyricmode { Stan -- za two a -- ligned }
Outro_lyrics    = \lyricmode { The end. }

% =====================================================================
% 5. THE STRUCTURAL BLUEPRINT ENGINE (Immutable)
% =====================================================================

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

% =====================================================================
% 6. ASSEMBLY (Single Source of Truth)
% =====================================================================

% 1. Build the Raw Master Timelines
chordsRaw = \buildStructuredContent "chords" \timeline
melodyRaw = \buildStructuredContent "melody" \timeline

% 2. Build Lyrics Lines (Identical rhythms mean straightforward assembly)
% THESE HAVE TO BE MANUALLY ADJUSTED TO REFLECT TIMELINE
lyricsLineOne = \lyricmode {
  \Intro_lyrics
  \set stanza = "1." \Verse_lyricsOne
  \set stanza = ""   \Outro_lyrics
}

lyricsLineTwo = \lyricmode {
  \skip 1 \skip 2. % Skip intro
  \set stanza = "2." \Verse_lyricsTwo
}

lyricsUnfolded = \lyricmode {
  \Intro_lyrics
  \Verse_lyricsOne
  \Verse_lyricsTwo
  \Outro_lyrics
}

% =====================================================================
% 7. PARTS DEFINITION
% =====================================================================

% The RAW part contains BOTH visual and MIDI layers
leadSheetPart = 
<<
  \new ChordNames \chordsRaw
  \new Staff \with { instrumentName = "Melody" } <<
    \global
    \new Voice = "vocalVoice" { \melodyRaw }
    
    \tag #'typeset {
      \new Lyrics \lyricsto "vocalVoice" { \lyricsLineOne }
    }
    \tag #'typeset {
      \new Lyrics \lyricsto "vocalVoice" { \lyricsLineTwo }
    }
    \tag #'unfolded {
      \new Lyrics \lyricsto "vocalVoice" { \lyricsUnfolded }
    }
  >>
>>

% =====================================================================
% 8. MASTER COMBINATION BLUEPRINTS
% =====================================================================

musicLeadSheet = {
  <<
    \new Devnull \timeline
    \leadSheetPart
  >>
}

% =====================================================================
% 9. TARGET OUTPUT SINGLE-BOOK COMPILATION
% =====================================================================

\book {
  \header { title = "Minimal Engine Core Template" }

  % --- SHEET 1: LEAD SHEET (FOLDED) ---
    \score {
      { \toLayout \musicLeadSheet }
      \layout { }
    }
  % --- SHEET 2: PLAYBACK CHECK (UNFOLDED) ---
    \score {
      { \toMidi \musicLeadSheet }
      \layout { }
      \midi { \tempo 4=120 }
    }
}
