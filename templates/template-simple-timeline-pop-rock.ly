\version "2.25.14"
\language "deutsch"
\include "predefined-guitar-fretboards.ly"

% =====================================================================
% 0. CONFIGURATION & GLOBALS
% =====================================================================

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
    \RemoveAllEmptyStaves  
  }
  \context {
    \DrumStaff
    \compressEmptyMeasures
    \RemoveAllEmptyStaves  
  }
}

global = {
  \key g \major
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

masterArrangementMap = #(list
  (cons "Intro"          #{ s1*2 #})
  (cons "VerseMainA"     #{ s1*2 #})
  (cons "VerseMainB"     #{ s1*1 #})
  (cons "VerseEndOne"    #{ s1*1 #})   
  (cons "VerseEndAltTwo" #{ s1*1 #})   
  (cons "Chorus"         #{ s1*2 #})
  (cons "Outro"          #{ s1*2 #})
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


asSmall = #(define-music-function (mus) (ly:music?)
  #{
    \voiceTwo % Keeps stems up/distinct from main melody
    \override NoteHead.font-size = #-2
    \override Stem.font-size = #-2
    \override Beam.beam-thickness = #0.3
    \override Rest.font-size = #-2
    #mus
    \revert NoteHead.font-size
    \revert Stem.font-size
    \revert Beam.beam-thickness
    \revert Rest.font-size
  #})

% Multiplexer: Wraps the diverging paths into tagged layers.
% It forces the main track's stems UP (\voiceOne) only during the variant, 
% automatically preventing visual collisions with the \voiceTwo small notes.
% Upgraded Multiplexer (Timeline Collapse Fixed)
variant = #(define-music-function (main-mus opt-mus) (ly:music? ly:music?)
  #{
    <<
      % --- 1. THE PRINTED SCORE LAYER (Simultaneous) ---
      \tag #'typeset {
        <<
          \tag #'mainTrack { \voiceOne #main-mus \oneVoice }
          \tag #'alignerTrack { #opt-mus }
          \tag #'optionalTrack { \tag #'variantTag { \asSmall #opt-mus } }
        >>
      }
      
      % --- 2. THE MIDI / UNFOLDED LAYER (Sequential) ---
      \tag #'playback {
        <<
          % We duplicate the sequential timeline into all three track tags.
          % This guarantees the timeline never collapses to 0 beats, 
          % no matter which track is being extracted.
          \tag #'mainTrack { \volta 1,3 { #main-mus } \volta 2 { #opt-mus } }
          \tag #'alignerTrack { \volta 1,3 { #main-mus } \volta 2 { #opt-mus } }
          \tag #'optionalTrack { \volta 1,3 { #main-mus } \volta 2 { #opt-mus } }
        >>
      }
    >>
  #})

% AST Filter: Walks the music tree. If it finds the \variantTag, it leaves those 
% specific notes alone. Otherwise, it converts all regular notes/rests into Skips.
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

makeSharedNotesSkips = #(define-music-function (mus) (ly:music?)
  (make-shared-skips mus))

% Multiplexer for additive harmonies. 
% It plays the main notes normally, but injects the harmony notes 
% ONLY into the optional visual track as small, secondary-voice notes.
addHarmony = #(define-music-function (main-mus harm-mus) (ly:music? ly:music?)
  #{
    <<
      #main-mus % The main melody continues as the rhythmic backbone
      \tag #'optionalTrack { \tag #'variantTag { \voiceTwo \asSmall #harm-mus } }
    >>
  #})


% =====================================================================
% 3. THE TIMELINE (Manually Editable Roadmap)
% =====================================================================

timeline = {
  \global
  \tag #'typeset { \sectionLabel "Intro" }             
  \Length_Intro
  \tag #'typeset { \section }
  
  \repeat segno 2 {
    
    % Force this break ONLY in the printed score
    % \tag #'typeset { \break }
    
    % --- PASS 1: The Printed & Played Loop ---
    \volta 1 {
      \repeat volta 2 {
        <<
          { \Length_VerseMainA \Length_VerseMainB }     
          {
            % \tag #'typeset { \sectionLabel "Verse" }
            s1*2                  
            \tag #'typeset { \mark \default }        
            s1                    
          }
        >>
        
        \tag #'typeset { \codaMark \default \break }
        
        \alternative {
          \volta 1 { \Length_VerseEndOne } 
          \volta 2 { \Length_VerseEndAltTwo } 
        }
        \tag #'typeset { \section }
      }
      
      \tag #'typeset { \sectionLabel "Chorus" }      
      \Length_Chorus              
      \tag #'typeset { \section }
    }
    
    % --- PASS 2: Unfolded / Playback-Only Pass ---
    \volta 2 {
      \unfolded {
        % We wrap this inside a dummy 3-pass repeat but only execute the 3rd pass!
        % This forces LilyPond's internal volta counter to '3', successfully
        % triggering the \volta 1,3 { ... } block defined inside \variant.
        \repeat volta 3 {
          \volta 3 {
            \Length_VerseMainA
            \Length_VerseMainB
          }
        }
      }
      \tag #'typeset { \section }
    }
  }
  
  % --- CODA ---
  \tag #'typeset { 
    \stopStaff s1 \startStaff 
    \undo \omit Score.CodaMark
    % \codaMark 1
    % \sectionLabel "Outro"
    \sectionLabel \markup { \bold "Coda" }

  }
  \Length_Outro                   
  \fine
}

% =====================================================================
% 4. RAW TRANSCRIPTION CHUNKS (G MAJOR)
% =====================================================================

% --- CHORDS ---
Intro_chords          = \chordmode { \globalChord g1 }
VerseMainA_chords     = \chordmode { \globalChord g1 c1 }
VerseMainB_chords     = \chordmode { \globalChord d1 }
VerseEndOne_chords    = \chordmode { \globalChord g1 }
VerseEndAltTwo_chords = \chordmode { \globalChord e1:m }
Chorus_chords         = \chordmode { \globalChord c1 d1 }
Outro_chords          = \chordmode { \globalChord g1*2 }

% --- MELODY & LYRICS ---
Intro_melody          = \relative c'' { R1 | r2. g8 g |  }
VerseMainA_melody     = \relative c'' { 
  % Beat 1: Shared
  g4 
  
  % Beat 2: Rhythmic Variant (Passes 1 and 3 output one rythm, Pass 2 outputs another)
  \variant { \fixed c' { a4 } } { \fixed c' { a8 fis8 } }
  
  % Beats 3 & 4: Main melody + Optional small harmony underneath
  \addHarmony { h4 c4 } { \parenthesize d4 < \parenthesize e \parenthesize a>4 }
  d2. r4 }

VerseMainB_melody     = \relative c'' { d4 c h a }
VerseEndOne_melody    = \relative c'' { g2 2 }
VerseEndAltTwo_melody = \relative c'' { h2 2 }
Chorus_melody         = \relative c'' { c4 c h h | a a g2 }
Outro_melody          = \relative c'' { g1 ~ | g1 }

Intro_lyrics             = \lyricmode { \globalLyrics Let's go }
VerseMainA_lyricsOne     = \lyricmode { \globalLyrics First verse op -- tion here }
VerseMainB_lyrics        = \lyricmode { \globalLyrics Shared part li -- nes }
VerseEndOne_lyricsOne    = \lyricmode { \globalLyrics end one }
VerseEndAltTwo_lyricsOne = \lyricmode { \globalLyrics end two }
Chorus_lyricsOne         = \lyricmode { \globalLyrics Si -- ng the cho -- rus lo -- ud __ }
Outro_lyricsOne          = \lyricmode { \globalLyrics Out __ }

VerseMainA_lyricsTwo     = \lyricmode { \globalLyrics Se -- cond verse op -- tion here }

% --- PIANO ---
Intro_pianoRight      = \relative c'' { <g h d>1 2. 4 }
VerseMainA_pianoRight = \relative c'' { <g h d>1 | <g c e>1 } 
VerseMainB_pianoRight = \relative c'' { <a d fis>1 }
VerseEndOne_pianoRight = \relative c'' { R1 }
VerseEndAltTwo_pianoRight = \relative c'' { R1 }
Chorus_pianoRight     = \relative c'' { <g c e>1 | <a d fis>1 }
Outro_pianoRight      = \relative c'' { R1*2 }

% --- E. PIANO ---
Intro_epianoRight      = \relative c'' { R1*2 }
VerseMainA_epianoRight = \relative c'' { r8 g h d~ d2 | r8 g, c e~ e2 }
VerseMainB_epianoRight = \relative c'' { r8 a d fis~ fis2 }
VerseEndOne_epianoRight = \relative c'' { R1 }
VerseEndAltTwo_epianoRight = \relative c'' { R1 }
Chorus_epianoRight     = \relative c'' { <g c e>2. r4 | <a d fis>2. r4 }
Outro_epianoRight      = \relative c'' { R1*2 }

% --- ORGAN (3 Voices) ---
Intro_organHigh = \relative c'' { \voiceOne h1~ 1 }
Intro_organMid  = \relative c'  { \voiceOne g1~ 1 }
Intro_organLow  = \relative c'  { \voiceTwo d1~ 1 }

VerseMainA_organHigh = \relative c'' { \voiceOne h1 | c1 }
VerseMainA_organMid  = \relative c'  { \voiceOne g1 | g1 }
VerseMainA_organLow  = \relative c'  { \voiceTwo d1 | e1 }

VerseMainB_organHigh = \relative c'' { \voiceOne a1 }
VerseMainB_organMid  = \relative c'  { \voiceOne fis1 }
VerseMainB_organLow  = \relative c'  { \voiceTwo d1 }

VerseEndOne_organHigh = \relative c'' { \voiceOne h1 }
VerseEndOne_organMid  = \relative c'  { \voiceOne g1 }
VerseEndOne_organLow  = \relative c'  { \voiceTwo d1 }

VerseEndAltTwo_organHigh = \relative c'' { \voiceOne g1 }
VerseEndAltTwo_organMid  = \relative c'  { \voiceOne e1 }
VerseEndAltTwo_organLow  = \relative c'  { \voiceTwo h1 }

Chorus_organHigh = \relative c'' { \voiceOne c1 | d1 }
Chorus_organMid  = \relative c'  { \voiceOne g1 | a1 }
Chorus_organLow  = \relative c'  { \voiceTwo e1 | fis1 }

Outro_organHigh = \relative c'' { \voiceOne h1 | h1 }
Outro_organMid  = \relative c'  { \voiceOne g1 | g1 }
Outro_organLow  = \relative c'  { \voiceTwo d1 | d1 }

% --- A. GUITAR ---
Intro_aguitar      = \relative c'' { g4\downbow g\upbow g\downbow g\upbow | g2 g }
VerseMainA_aguitar = \relative c'' { g4 g g g | c4 c c c }
VerseMainB_aguitar = \relative c'' { d4 d d d }
VerseEndOne_aguitar = \relative c'' { R1 }
VerseEndAltTwo_aguitar = \relative c'' { R1 }
Chorus_aguitar     = \relative c'' { c4 c c c | d4 d d d }
Outro_aguitar      = \relative c'' { R1*2 }

% --- E. GUITAR (2 Voices: Patterns & Chords) ---
Intro_eguitarOne = \relative c'' { d8( e) d4 r2 | R1 }
Intro_eguitarTwo = \relative c'' { <g, h d>1 | q4 4 4 r4 }

VerseMainA_eguitarOne = \relative c'' { r4 d8( e) d2 | r4 e8( g) e2 }
VerseMainA_eguitarTwo = \relative c'' { <g, h d>1 | <g c e>1 }

VerseMainB_eguitarOne = \relative c'' { fis8( e) d4 r2 }
VerseMainB_eguitarTwo = \relative c'' { <a d fis>1 }

VerseEndOne_eguitarOne = \relative c'' { R1 }
VerseEndOne_eguitarTwo = \relative c'' { R1 }

VerseEndAltTwo_eguitarOne = \relative c'' { R1 }
VerseEndAltTwo_eguitarTwo = \relative c'' { R1 }

Chorus_eguitarOne = \relative c'' { r4 c8 d e4 r | r4 d8 e fis4 r }
Chorus_eguitarTwo = \relative c'' { <g, c e>1 | <a d fis>1 }

Outro_eguitarOne = \relative c'' { R1*2 }
Outro_eguitarTwo = \relative c'' { R1*2 }

% --- E. BASS ---
Intro_bass      = \relative c { g4 d g r | g4 d g r }
VerseMainA_bass = \relative c { g4 d g r | c4 g c r }
VerseMainB_bass = \relative c { d4 a d r }
VerseEndOne_bass = \relative c { g1 }
VerseEndAltTwo_bass = \relative c { e1 }
Chorus_bass     = \relative c { c4. g8 c4 r | d4. a8 d4 r }
Outro_bass      = \relative c { g1 ~ | g1 }

% --- DRUMS ---
Intro_drums      = \drummode { bd4 sn bd sn | bd4 sn bd sn }
VerseMainA_drums = \drummode { hh4 hh hh hh | hh hh hh hh }
VerseMainB_drums = \drummode { bd4 sn bd sn }
VerseEndOne_drums = \drummode { bd1 }
VerseEndAltTwo_drums = \drummode { bd1 }
Chorus_drums     = \drummode { cymr4 hh cymr hh | cymr hh cymr hh }
Outro_drums      = \drummode { bd1 | cymc1 }

% --- STRINGS ---
Intro_violinOne = \relative c'' { R1 }
Intro_violinTwo = \relative c'' { R1 }
Intro_viola     = \relative c'  { R1 }
Intro_cello     = \relative c   { R1 }

VerseMainA_violinOne = \relative c'' { R1*2 }
VerseMainA_violinTwo = \relative c'' { R1*2 }
VerseMainA_viola     = \relative c'  { R1*2 }
VerseMainA_cello     = \relative c   { R1*2 }

VerseMainB_violinOne = \relative c'' { d1 }
VerseMainB_violinTwo = \relative c'' { a1 }
VerseMainB_viola     = \relative c'  { fis1 }
VerseMainB_cello     = \relative c   { d1 }

VerseEndOne_violinOne = \relative c'' { R1 }
VerseEndOne_violinTwo = \relative c'' { R1 }
VerseEndOne_viola     = \relative c'  { R1 }
VerseEndOne_cello     = \relative c   { R1 }

VerseEndAltTwo_violinOne = \relative c'' { R1 }
VerseEndAltTwo_violinTwo = \relative c'' { R1 }
VerseEndAltTwo_viola     = \relative c'  { R1 }
VerseEndAltTwo_cello     = \relative c   { R1 }

Chorus_violinOne = \relative c'' { e1 | fis1 }
Chorus_violinTwo = \relative c'' { c1 | d1 }
Chorus_viola     = \relative c'  { g1 | a1 }
Chorus_cello     = \relative c   { c1 | d1 }

Outro_violinOne = \relative c'' { d1 | d1 }
Outro_violinTwo = \relative c'' { h1 | h1 }
Outro_viola     = \relative c'  { g1 | g1 }
Outro_cello     = \relative c   { g1 | g1 }

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
% 6. ASSEMBLY (Single Source of Truth) - Two-tier for optional Verses
% =====================================================================
% Note on Routing Tiers: 
% 1. GLOBAL ROUTING (\toLayout / \toMidi): Manages the Macro output (Print vs. MIDI Playback loop).
% 2. INTERNAL ROUTING (Below): Acts as a prism for the melody staff. It splits \melodyRaw 
%    into separate Voice/NullVoice streams to handle visual formatting and separate lyrical 
%    rhythms (Stanza 1 vs Stanza 2) without causing collisions or breaking \lyricsto alignment.
% =====================================================================
chordsNames  = \buildStructuredContent "chords" \timeline

% 1. Build the Raw Master Timeline
melodyRaw    = \buildStructuredContent "melody" \timeline

% 2. Extract the specific layers
% (Keep both 'typeset and 'playback alive here)
melody          = \removeWithTag #'alignerTrack \removeWithTag #'optionalTrack \melodyRaw
melody_aligner  = \removeWithTag #'mainTrack \removeWithTag #'optionalTrack \melodyRaw
melody_optional = \makeSharedNotesSkips \removeWithTag #'mainTrack \removeWithTag #'alignerTrack \melodyRaw


pianoRight   = \buildStructuredContent "pianoRight" \timeline
epianoRight  = \buildStructuredContent "epianoRight" \timeline

organHigh    = \buildStructuredContent "organHigh" \timeline
organMid     = \buildStructuredContent "organMid" \timeline
organLow     = \buildStructuredContent "organLow" \timeline

% Combining Organ into a single track variable
organTrack = \new Voice << \organHigh \organMid \organLow >>

aguitar      = \buildStructuredContent "aguitar" \timeline
eguitarOne   = \buildStructuredContent "eguitarOne" \timeline
eguitarTwo   = \buildStructuredContent "eguitarTwo" \timeline
bass         = \buildStructuredContent "bass" \timeline
drumsTrack   = \buildStructuredContent "drums" \timeline

violinOne    = \buildStructuredContent "violinOne" \timeline
violinTwo    = \buildStructuredContent "violinTwo" \timeline
viola        = \buildStructuredContent "viola" \timeline
cello        = \buildStructuredContent "cello" \timeline

% --- LYRICS GENERATION ---
lyricsLineOne = \lyricmode {
  \Intro_lyrics
  \set stanza = "1. 3."
  \VerseMainA_lyricsOne
  \set stanza = "" 
  \VerseMainB_lyrics
  \VerseEndOne_lyricsOne
  \VerseEndAltTwo_lyricsOne
  \Chorus_lyricsOne
  \Outro_lyricsOne
}

lyricsLineTwo = \lyricmode {
  \skip 1*1 \skip 2.  % skips to end of bar preceding verse
  \set stanza = "2."
  \VerseMainA_lyricsTwo
}

lyricsUnfolded = \lyricmode {
  \Intro_lyrics
  \VerseMainA_lyricsOne \VerseMainB_lyrics \VerseEndOne_lyricsOne
  \VerseMainA_lyricsTwo \VerseMainB_lyrics \VerseEndAltTwo_lyricsOne
  \Chorus_lyricsOne
  \VerseMainA_lyricsOne \VerseMainB_lyrics
  \Outro_lyricsOne
}

% =====================================================================
% 7. PARTS DEFINITION
% =====================================================================

% This section defines the RAW parts (These contain BOTH visual and MIDI layers)
% Architecture: Unified "Raw" blueprints serve as a Single Source of Truth for both print and playback.
% Compilation: Dynamically filtered at the score level using semantic switches (\toLayout and \toMidi).

% =====================================================================
% SEMANTIC OUTPUT SWITCHES
% =====================================================================

% Automatically prepares any raw blueprint for the visual PDF layout
toLayout = #(define-music-function (mus) (ly:music?)
  #{ \removeWithTag #'unfolded \removeWithTag #'playback #mus #})

% Automatically prepares any raw blueprint for unfolded MIDI playback
toMidi = #(define-music-function (mus) (ly:music?)
  #{ \removeWithTag #'typeset \unfoldRepeats #mus #})

% =====================================================================
% PARTS
% =====================================================================

leadSheetPart = 
\new ChoirStaff \with {\accepts NullVoice } <<
  \new ChordNames \chordsNames
  \new Staff \with { 
    instrumentName = "Melody" 
    \accepts NullVoice
  } <<
    \global
    \new Voice = "vocalVoice" { \melody }
    \new Voice = "optionalVoice" { \melody_optional }
    \new NullVoice = "aligner" { \melody_aligner }
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

% % 2. Filter to only keep the parts for the PRINTED PDF (Strips MIDI tags permanently)
% leadSheetPart     = \removeWithTag #'unfolded \removeWithTag #'playback \leadSheetPartRaw

pianoPart = \new PianoStaff \with { 
  instrumentName = "Piano" 
} <<
  \new Staff = "up" { \global \pianoRight }
  % \new Dynamics { \pianoDynamics }
  % \new Staff = "down" { \global \clef bass \pianoLeft }
>>

keyboardsPart = \new ChoirStaff <<
  \new Staff \with { instrumentName = "Piano" } { \global \pianoRight }
  \new Staff \with { instrumentName = "E.Piano" } { \global \epianoRight }
  \new Staff \with { instrumentName = "Organ" } { \global \organTrack }
>>

aguitarPart = <<
  \new Staff \with { instrumentName = "A.Guitar" } <<
    \global
    \new Voice { \aguitar }
    % \new Dynamics { \guitarDynamics }
  >>
  \new TabStaff {
    \global
    \new TabVoice { \aguitar }
  }
>>

fretsPart = <<
  \new Staff \with { instrumentName = "A.Guitar" } { \global \aguitar }
  \new Staff \with { instrumentName = "E.Guitar" } <<
    \global
    \new Voice { \voiceOne \eguitarOne }
    \new Voice { \voiceTwo \eguitarTwo }
  >>
  \new Staff \with { instrumentName = "Bass" } { \global \clef bass \bass }
>>


drumsPart = \new DrumStaff \with {
  instrumentName = "Drums"
  shortInstrumentName = "Dr."
} {
  \drumsTrack
}


rhythmSectionPart = <<
  \new Staff \with { instrumentName = "Piano" } { \global \pianoRight }
  \new Staff \with { instrumentName = "E.Piano" } { \global \epianoRight }
  \new Staff \with { instrumentName = "Organ" } { \global \organTrack }
  \new Staff \with { instrumentName = "A.Guitar" } { \global \aguitar }
  \new Staff \with { instrumentName = "E.Guitar" } <<
    \global
    \new Voice { \voiceOne \eguitarOne }
    \new Voice { \voiceTwo \eguitarTwo }
  >>
  \new Staff \with { instrumentName = "Bass" } { \global \clef bass \bass }
  \new DrumStaff \with { instrumentName = "Drums" } { \drumsTrack }
>>

stringSectionPart = \new StaffGroup \with { instrumentName = "Strings" } <<
  \new Staff \with { shortInstrumentName = "Vl.1" } { \global \violinOne }
  \new Staff \with { shortInstrumentName = "Vl.2" } { \global \violinTwo }
  \new Staff \with { shortInstrumentName = "Vla." } { \global \clef alto \viola }
  \new Staff \with { shortInstrumentName = "Vc." } { \global \clef bass \cello }
>>

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

musicPianoVocal = {
  <<
    \new Devnull \timeline
    \leadSheetPart
    \keyboardsPart
  >>
}

musicFrets = {
  <<
    \new Devnull \timeline
    \fretsPart
  >>
}

musicStrings = {
  <<
    \new Devnull \timeline
    \stringSectionPart
  >>
}


% =====================================================================
% 8. OUTPUT COMPILATION
% =====================================================================

\book {
  
  \header {
    title = "Arrangement Master Template"
    composer = "Composer Name"
    arranger = "Arranger Name"
    copyright = "© 2026 M2B"
    tagline = "Engraved 2026 by M2B"
  }
  
  % --- PART 1: FULL CONDUCTOR SCORE ---
  \bookpart {
    \header { subtitle = "Conductor's Full Score" }
    \score {
      { \toLayout \musicFullScore }
      \layout { #(layout-set-staff-size 15) }
    }
    \score {
      \toMidi \musicFullScore
      \midi { \tempo 4=120 }
    }
  }

  % --- PART 2: LEAD SHEET ---
  \bookpart {
    \header { subtitle = "Lead Sheet" }
    \score {
      { \toLayout \musicLeadSheet }
    }
    \score {
      \toMidi \musicLeadSheet
      \midi { \tempo 4=120 }
    }
  }

  % --- PART 3: PIANO & VOCAL INTERMEDIATE SCORE ---
  \bookpart {
    \header { subtitle = "Piano / Vocal Score" }
    \score {
      { \toLayout \musicPianoVocal }
    }
    \score {
      \toMidi \musicPianoVocal
      \midi { \tempo 4=120 }
    }
  }
  
  % --- PART 4: FRETTED STRINGS ---
  \bookpart {
    \header { subtitle = "Guitar Performance Layout" }
    \score {
      { \toLayout \musicFrets }
    }
    \score {
      \toMidi \musicFrets
      \midi { \tempo 4=120 }
    }
  }
  
  % --- PART 4: ARRANGEMENT ---
  \bookpart {
    \header { subtitle = "2. String Quartet Arrangement" }
    \score {
      { \removeWithTag #'unfolded << \new Devnull \timeline \stringSectionPart >> }
      \layout { #(layout-set-staff-size 15) }
    }
  }
  
  \bookpart {
    \header { subtitle = "3. Playback / Unfolded Check" }
    \score {
      \toMidi \musicLeadSheet
      \midi { \tempo 4=110 }
      \layout { #(layout-set-staff-size 15) }    }
  }

}
