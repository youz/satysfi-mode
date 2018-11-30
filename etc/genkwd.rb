require 'yaml'

# usage:
# ruby genkwd.rb path/to/vminstdef.yaml >satysfi

prims = []
ops   = []

YAML.load_stream(ARGF.read) do |inst|
  if (inst["is-pdf-mode-primitive"] || inst["is-text-mode-primitive"]) && inst["name"] != nil then
    case inst["name"]
    when "not"
      ops
    when "mod"
      ops
    when /^\W+$/
      ops
    else
      prims
    end << inst["name"]
  end
end

puts <<__KEYWORDFILE__
; -*- mode:satysfi -*-
;*0
;; keywords (from SATySFi/src/frontend/lexer.mll)
if
then
else
let
let-rec
and
in
fun
true
false
before
while
do
let-mutable
match
with
when
as
type
of
module
struct
sig
val
end
direct
constraint
let-inline
let-block
let-math
controls
cycle
inline-cmd
block-cmd
math-cmd
command
open

;*2
;; base types (from src/frontend/types_template.ml base_type_hash_table)
unit
bool
int
float
length
string
inline-text
block-text
inline-boxes
block-boxes
context
pre-path
path
graphics
image
document
math
regexp

list
ref

;; data types & constructors (from src/frontend/primitives_template.ml)
option
Some
None

itemize
Item

script
HanIdeographic
Kana
Latin
OtherScript

language
English
Japanese
NoLanguageSystem

color
Gray
RGB
CMYK

page
A0Paper
A1Paper
A2Paper
A3Paper
A4Paper
A5Paper
USLetter
USLegal
UserDefinedPaper

mathcls
MathOrd
MathBin
MathRel
MathOp
MathPunct
MathOpen
MathClose
MathPrefix

mccls
MathItalic
MathBoldItalic
MathRoman
MathBoldRoman
MathScript
MathBoldScript
MathFraktur
MathBoldFraktur
MathDoubleStruck

cell
NormalCell
EmptyCell
MultiCell

;; alias
deco
deco-set

;; primitives (from SATySFi/src/frontend/bytecomp/vminstdef.yaml)
;*0
#{ops * "\n"}

;*1
#{prims * "\n"}
__KEYWORDFILE__

