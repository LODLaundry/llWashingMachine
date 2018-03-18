:- module(
  ll_document,
  [
    ll_document/3 % +Directory, +Name, +Uri
  ]
).

/** <module> LOD Laundromat: Scrape one document

@author Wouter Beek
@version 2017-2018
*/

:- use_module(library(debug)).
:- use_module(library(settings)).

:- use_module(library(archive_ext)).
:- use_module(library(atom_ext)).
:- use_module(library(default)).
:- use_module(library(hash_ext)).
:- use_module(library(http/http_client2)).
:- use_module(library(media_type)).
:- use_module(library(settings)).
:- use_module(library(stream_ext)).
:- use_module(library(string_ext)).
:- use_module(library(sw/rdf_clean)).
:- use_module(library(sw/rdf_deref)).
:- use_module(library(sw/rdf_export)).
:- use_module(library(sw/rdf_guess)).
:- use_module(library(sw/rdf_media_type)).
:- use_module(library(sw/rdf_term)).
:- use_module(library(uri_ext)).
:- use_module(library(xml_ext)).

%! ll_document_debug(?OName:atom, ?DName:atom, ?Url:atom, ?Entry:atom) is nondet.
%
% Gives the ability to debug a specific dataset/file/entry.

%! ll_document_skip(?OName:atom, ?DName:atom, ?Url:atom, ?Entry:atom) is nondet.
%
% Gives the ability to skip specific entries in a large archive, in
% order to sooner arrive at a ll_document_debug/4 instance.

:- dynamic
    ll_document_debug/4,
    ll_document_skip/4.

%ll_document_debug(
%  something,
%  'dbpedia-el',
%  'http://el.dbpedia.org/data/Linux.n3',
%  data
%).

:- initialization
   set_setting(rdf_term:bnode_prefix_scheme, http),
   set_setting(rdf_term:bnode_prefix_authority, 'lodlaundromat.org').





%! ll_document(+Directory:atom, +Name:pair(atom), +Uri:atom) is det.

ll_document(Dir, Name, Uri0) :-
  % Make sure that non-ASCII Unicode characters are percent encoded.
  uri_normalized(Uri0, Uri),
  http_open2(Uri, In, [failure(-1),metadata(Metas)]),
  call_cleanup(
    (
      % Use a dummy value in case the Media Type cannot be determined.
      call_default_value(MediaType, http_metadata_content_type(Metas), null),
      download_from_uri(Name, Dir, Uri, MediaType, In)
    ),
    close(In)
  ).

download_from_uri(Name, Dir, Uri, MediaType, In) :-
  setup_call_cleanup(
    archive_open(In, Archive),
    download_from_archive(Name, Dir, Uri, MediaType, Archive),
    archive_close(Archive)
  ).

download_from_archive(Name, Dir, Uri, MediaType, Archive) :-
  forall(
    archive_data_stream(Archive, In, [meta_data(Metas)]),
    call_cleanup(
      download_from_archive_stream(Name, Dir, Uri, MediaType, Metas, In),
      close(In)
    )
  ).

download_from_archive_stream(OName-DName, Dir, Uri, MediaType, [Meta|_], In) :-
  _{name: Entry} :< Meta,
  debug(ll, "~a ~a", [Uri,Entry]),
  \+ ll_document_skip(OName, DName, Uri, Entry),
  (ll_document_debug(OName, DName, Uri, Entry) -> gtrace ; true),
  peek_string(In, 10 000, String),
  guess_encoding(MediaType, String, Encoding),
  download_from_entry(OName-DName, Dir, Uri-Entry, Encoding, In).

guess_encoding(MediaType, String, Encoding) :-
  ignore(xml_encoding_(String, EncodingXml)),
  ignore(media_type_encoding(MediaType, EncodingMediaType)),
  ignore(guess_encoding_(String, EncodingGuess)),
  choose_encoding(EncodingXml, EncodingMediaType, EncodingGuess, Encoding),
  warn_encoding(EncodingXml, EncodingMediaType, EncodingGuess, Encoding).

guess_encoding_(String, Encoding) :-
  setup_call_cleanup(
    open_string(String, In),
    guess_encoding(In, Encoding),
    close(In)
  ),
  Encoding \== unknown.

xml_encoding_(String, Encoding) :-
  setup_call_cleanup(
    open_string(String, In),
    xml_encoding(In, Encoding),
    close(In)
  ).

% Encoding specified in the XML header.
choose_encoding(Xml, _, _, Xml) :-
  ground(Xml), !.
% Encoding specified in the Media Type.
choose_encoding(_, MediaType, _, MediaType) :-
  ground(MediaType), !.
% Guessed encoding.
choose_encoding(_, _, Guess, Guess).

warn_encoding(A, B, C, D) :-
  maplist(generalize_encoding, [A,B,C], [X,Y,Z]),
  include(ground, [X,Y,Z], L),
  list_to_ord_set(L, S),
  (   S = [_,_|_]
  ->  print_message(warning, unclear_encoding([X,Y,Z],D))
  ;   true
  ).

generalize_encoding(Var, Var) :-
  var(Var), !.
generalize_encoding(ascii, utf8) :- !.
generalize_encoding(unknown, _Var) :- !.
generalize_encoding(Encoding, Encoding).

download_from_entry(Name, Dir, Uri-Entry, unknown, In) :- !,
  download_from_entry_stream(Name, Dir, Uri-Entry, In).
download_from_entry(Name, Dir, Uri-Entry, Encoding, In) :-
  recode_stream(Encoding, In), !,
  download_from_entry_stream(Name, Dir, Uri-Entry, In).
download_from_entry(Name, Dir, Uri-Entry, Encoding, In1) :-
  setup_call_cleanup(
    recode_stream(Encoding, In1, In2),
    download_from_entry_stream(Name, Dir, Uri-Entry, In2),
    close(In2)
  ).

download_from_entry_stream(OName-DName, Dir, Uri-Entry, In) :-
  % After recoding, the stream needs to be peeked again.  Not only
  % because the stream can have changed (which could be detected with
  % (==)/2, but also because the same stream can have different
  % settings now.
  peek_string(In, 10 000, String),
  (   rdf_guess_string(String, MediaType)
  ->  (   rdfa_media_type(MediaType)
      ->  % The entire peeked string can be too long for a warning
          % message.
          (string_prefix(String, 100, Content) -> true ; Content = String),
          print_message(warning, rdf(unsupported_format(MediaType,Content)))
      ;   bnode_prefix_([OName,DName,Entry], BNodePrefix),
          md5(Uri-Entry, Base),
          file_name_extension(Base, 'trig.gz', File),
          directory_file_path(Dir, File, Path),
          setup_call_cleanup(
            gzopen(Path, write, Out),
            download_rdf(Uri, In, BNodePrefix, MediaType, Out),
            close(Out)
          )
      )
  ;   % The entire peeked string can be too long for a warning
      % message.
      (string_prefix(String, 100, Content) -> true ; Content = String),
      print_message(warning, rdf(non_rdf_format(Uri-Entry,Content)))
  ).

bnode_prefix_(Segments, BNodePrefix) :-
  setting(rdf_term:bnode_prefix_scheme, Scheme),
  setting(rdf_term:bnode_prefix_authority, Auth),
  uri_comps(BNodePrefix, uri(Scheme,Auth,['.well-known',genid|Segments],_,_)).

download_rdf(Uri, In, BNodePrefix, MediaType, Out) :-
  format(Out, "<~a> {\n", [Uri]),
  rdf_deref_stream(
    Uri,
    In,
    clean_tuples(Out),
    [bnode_prefix(BNodePrefix),media_type(MediaType)]
  ),
  format(Out, "}\n", []).

clean_tuples(Out, BNodePrefix, Tuples, _) :-
  maplist(clean_tuple(Out, BNodePrefix), Tuples).

clean_tuple(Out, BNodePrefix, rdf(S0,P0,O0)) :- !,
  (   rdf_clean_triple(BNodePrefix, rdf(S0,P0,O0), rdf(S,P,O))
  ->  rdf_write_triple(Out, BNodePrefix, S, P, O)
  ;   true
  ).
clean_tuple(Out, BNodePrefix, rdf(S,P,O,_)) :-
  clean_tuple(Out, BNodePrefix, rdf(S,P,O)).
