:- module(
  lwm_clean,
  [
    lwm_clean_loop/2 % +Category:atom
                     % :Goal
  ]
).

/** <module> LOD Washing Machine: cleaning

The cleaning process performed by the LOD Washing Machine.

@author Wouter Beek
@version 2014/03-2014/06, 2014/08-2014/09
*/

:- use_module(library(aggregate)).
:- use_module(library(apply)).
:- use_module(library(option)).
:- use_module(library(semweb/rdf_db)).
:- use_module(library(zlib)).

:- use_module(pl(pl_log)).

:- use_module(plRdf_ser(ctriples_write_graph)).
:- use_module(plRdf_ser(rdf_file_db)).
:- use_module(plRdf_ser(rdf_guess_format)).

:- use_module(lwm(lwm_debug_message)).
:- use_module(lwm(lwm_sparql_query)).
:- use_module(lwm(lwm_store_triple)).
:- use_module(lwm(md5)).
:- use_module(lwm(noRdf_store)).

:- meta_predicate(lwm_clean_loop(+,1)).

:- dynamic(debug:debug_md5/2).
:- multifile(debug:debug_md5/2).



lwm_clean_loop(Category, Goal):-
  % Pick a new source to process.
  % If some exception is thrown here, the catch/3 makes it
  % silently fail. This way, the unpacking thread is able
  % to wait in case a SPARQL endpoint is temporarily down.
  catch(
    with_mutex(lod_washing_machine, (
      lwm_sparql_select(
        [llo],
        [datadoc,size],
        [
          rdf(var(datadoc),llo:endUnpack,var(endUnpack)),
          not([rdf(var(datadoc),llo:startClean,var(startClean))]),
          rdf(var(datadoc),llo:size,var(size))
        ],
        [[Datadoc,literal(type(_,NumberOfBytes1))]],
        [limit(1)]
      ),

      % Do not process dirty data documents for which the given goal
      % does not succeed when applied to the dirty document's size.
      (   nonvar(Goal)
      ->  atom_number(NumberOfBytes1, NumberOfBytes2),
          NumberOfGigabytes is NumberOfBytes2 / (1024 ** 3),
          call(Goal, NumberOfGigabytes)
      ;   true
      ),

      % Tell the triple store we are now going to clean this MD5.
      rdf_global_id(ll:Md5, Datadoc),
      store_start_clean(Datadoc)
    )),
    Exception,
    var(Exception)
  ), !,

  % DEB
  (   debug:debug_md5(Md5, clean)
  ->  gtrace
  ;   true
  ),

  % Process the URL we picked.
  lwm_clean(Category, Md5, Datadoc),

  %%%%% Make sure the unpacking threads do not create a pending pool
  %%%%% that is (much) too big.
  %%%%flag(number_of_pending_md5s, Id, Id - 1),

  % Intermittent loop.
  lwm_clean_loop(Category, Goal).
% Done for now. Check whether there are new jobs in one seconds.
lwm_clean_loop(Category, Goal):-
  sleep(30),

  % DEB
  lwm_debug_message(lwm_idle_loop(Category)),

  lwm_clean_loop(Category, Goal).


%! lwm_clean(+Category:atom, +Md5:atom, +Datadoc:url) is det.

lwm_clean(Category, Md5, Datadoc):-
  % DEB
  lwm_debug_message(
    lwm_progress(Category),
    lwm_start(Category,Datadoc,Source)
  ),

  run_collect_messages(
    clean_md5(Category, Md5, Datadoc),
    Status,
    Warnings
  ),

  % DEB
  lwm_debug_message(
    lwm_progress(Category),
    lwm_end(Category,Md5,Source,Status,Warnings)
  ),

  store_exception(Datadoc, Status),
  maplist(store_warning(Datadoc), Warnings),
  store_end_clean(Md5, Datadoc).


%! clean_md5(+Category:atom, +Md5:atom, +Datadoc:url) is det.

clean_md5(Category, Md5, Datadoc):-
  % Construct the file name belonging to the given MD5.
  md5_directory(Md5, Md5Dir),
  absolute_file_name(dirty, DirtyFile, [access(read),relative_to(Md5Dir)]),

  % Retrieve the content type, if it was previously determined.
  datadoc_content_type(Datadoc, ContentType),

  % Clean the data document in an RDF transaction.
  setup_call_cleanup(
    open(DirtyFile, read, Read),
    (
      rdf_transaction(
        clean_datastream(
          Category,
          Md5,
          Datadoc,
          DirtyFile,
          Read,
          ContentType,
          VoidUrls
        ),
        _,
        [snapshot(true)]
      ),
      store_stream(Datadoc, Read)
    ),
    close(Read)
  ),

  % Keep the old/dirty file around in compressed form,
  % or throw it away.
  %%%%archive_create(DirtyFile, _),
  delete_file(DirtyFile),

  % Add the new VoID URLs to the LOD Basket.
  store_new_urls(VoidUrls).


%! clean_datastream(
%!   +Category:atom,
%!   +Md5:atom,
%!   +Datadoc:url,
%!   +File:atom,
%!   +Read:blob,
%!   +ContentType:atom,
%!   -VoidUrls:ordset(url)
%! ) is det.

clean_datastream(
  Category,
  Md5,
  Datadoc,
  File,
  Read,
  ContentType,
  VoidUrls
):-
  % Guess the RDF serialization format,
  % using the content type and the file extension as suggestions.
  ignore(datadoc_file_extension(Datadoc, FileExtension)),
  rdf_guess_format(Datadoc, Read, FileExtension, ContentType, Format),
  rdf_serialization(_, _, Format, _, Uri),
  store_triple(Datadoc, llo-serializationFormat, Uri),

  % Load all triples by parsing the data document
  % according to the guessed RDF serialization format.
  md5_base_url(Md5, Base),
  Options1 =
      [base_uri(Base),format(Format),graph(user),register_namespaces(false)],

  % Add options that are specific to the RDFa serialization format.
  (   Format == rdfa
  ->  merge_options([max_errors(-1),syntax(style)], Options1, Options2)
  ;   Options2 = Options1
  ),

  rdf_load(stream(Read), Options2),

  % In between loading and saving the data,
  % we count the number of triples, including the number of duplicates.
  aggregate_all(
    count,
    rdf(_, _, _, _),
    TIn
  ),

  % Save the data in a cleaned format.
  save_data_to_file(Md5, File, TOut),

  % Store statistics about the number of (duplicate) triples.
  store_number_of_triples(Category, Datadoc, TIn, TOut),

  % Make sure any VoID datadumps are added to the LOD Basket.
  find_void_datasets(Category, VoidUrls).



% Helpers

%! clean_file_name(+File:atom, +Format:oneof([quads,triples])) is det.

clean_file_name(_, triples):- !.
clean_file_name(File1, quads):-
  file_directory_name(File1, Dir),
  directory_file_path(Dir, 'clean.nq.gz', File2),
  rename_file(File1, File2).


%! find_void_datasets(+Category:atom, -VoidUrls:ordset(url)) is det.

find_void_datasets(Category, Urls):-
  aggregate_all(
    set(Url),
    rdf(_, void:dataDump, Url),
    Urls
  ),

  % DEB
  lwm_debug_message(lwm_process(Category), void_found(Urls)).


%! rdf_guess_format(
%!   +Datadoc:url,
%!   +Read:blob,
%!   +FileExtension:atom,
%!   +ContentType:atom,
%!   -Format:atom
%! ) is semidet.

rdf_guess_format(_, Read, FileExtension, ContentType, Format):-
  rdf_guess_format(Read, FileExtension, ContentType, Format), !.
rdf_guess_format(Datadoc, _, _, _, _):-
  datadoc_source(Datadoc, Source),
  throw(error(no_rdf(Source))).


%! save_data_to_file(+Md5:atom, +File:atom, -NumberOfTriples:nonneg) is det.

save_data_to_file(Md5, File, NumberOfTriples):-
  file_directory_name(File, Dir),
  directory_file_path(Dir, 'clean.nt.gz', CleanFile),
  md5_bnode_base(Md5, BaseComponents),
  setup_call_cleanup(
    gzopen(CleanFile, write, Write),
    ctriples_write_graph(
      Write,
      _NoGraph,
      [
        bnode_base(BaseComponents),
        format(Format),
        number_of_triples(NumberOfTriples)
      ]
    ),
    close(Write)
  ),
  % Fix the file name, if needed.
  clean_file_name(CleanFile, Format).

