:- module(
  lwm_debug_message,
  [
    end_process//5, % +Category:oneof([clean,unpack])
                    % +Document:iri
                    % +Origin:url
                    % +Status:or([boolean,compound])
                    % +Warnings:list(compound)
    idle_loop//1, % +Category:oneof([clean,unpack])
    start_process//3, % +Category, +Document, +Origin
    start_process//4 % +Category:oneof([clean,unpack])
                     % +Document:iri
                     % +Origin:url
                     % +Size:number
  ]
).

/** <module> LOD Washing Machine: Debug Message

Prints debug messages for the LOD Washing Machine.

@author Wouter Beek
@version 2015/11
*/

:- use_module(library(apply)).
:- use_module(library(counter)).
:- use_module(library(dcg/basics)).
:- use_module(library(dcg/dcg_atom)).
:- use_module(library(default)).
:- use_module(library(debug)).
:- use_module(library(lodapi/lodapi_generics)).




%! category(+Category:oneof([clean,unpack]))// is det.
% Print a category name.

category(Category) -->
  upper_atom(Category).



%! document_name(+Document:iri)// is det.

document_name(Doc) -->
  {document_name(Doc, Name},
  atom(Name).
  



%! end_process(
%!   +Category:oneof([clean,unpack]),
%!   +Document:iri,
%!   +Origin:url,
%!   +Status:or([boolean,compound]),
%!   +Warnings:list(compound)
%! )// is det.

end_process(Category, Doc, Origin, Status, Warnings) -->
  "[END ", category(Category), "] ",
  status(Status), " "
  document_name(Doc), " ",
  atom(Origin).



%! idle_loop(+Category:oneof([clean,unpack]))// is det.
% Print the fact that an idle loop is being traversed.

idle_loop(Category) -->
  % Every category has its own idle loop counter.
  {increment_counter(number_of_idle_loops(Category), N)},
  "[IDLE ", category(Cat), "] ", integer(N).



%! simpleRdf_written(
%!   +NumberOfUniqueTriples:nonneg,
%!   +NumberOfDuplicateTriples:nonneg
%! )// is det.
% Prints how many Simple-RDF statements were written.
%
% @tbd Quadruples?

simpleRdf_written(0, _) --> !, "".
simpleRdf_written(NumberOfUniqueTriples, NumberOfDuplicateTriples) -->
  "[+", integer(NumberOfUniqueTriples),
  (   {NumberOfDuplicateTriples =:= 0}
  ->  ""
  ;   " (", integer(NumberOfDuplicateTriples), " duplicates)"
  ),
  "]".



%! size(+Size:number)// is det.
% Prints a stream size indicator.
% Size is the number of megabytes.

size(Size) --> {var(Size)}, !, "".
size(Size) -->
  " (", 
  {NumberOfGigabytes is Size / (1024 ** 3)},
  float(NumberOfGigabytes),
  " GB)".



%! start_process(
%!   +Category:oneof([clean,unpack]),
%!   +Document:iri,
%!   +Origin:url
%! )// is det.
% Wrapper around start_process//4 with no size indicator.

start_process(Category, Doc, Origin) -->
  start_process(Category, Doc, Origin, _).


%! start_process(
%!   +Category:oneof([clean,unpack]),
%!   +Document:iri,
%!   +Origin:url,
%!   +Size:number
%! )// is det.
% Prints the start of a LOD Washing Machine process.

start_process(Process, Doc, Origin, SizeString) -->
  "START ", atom_upper(Process), " ", document_name(Doc), nl,
  "  ", atom(Origin), nl
  "  ", size(Size).



%! status(+Status:or([boolean,compound]))// is det.
% Prints the given LOD Washing Machine process status.

status(true) --> !, "".
status(false) --> "  FAILED ".
status(Status) --> "  [STATUS] ", pl_term(Status).



%! void_found(+Urls:list(url))// is det.
% Prints the fact that seed points have been found inside VoID descriptions.

void_found([]) --> !, "".
void_found([H|T]) --> "  [VOID] ", atom(H), void_found(T).
