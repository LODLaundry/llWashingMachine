:- module(ll_init, []).

/** <module> LOD Laundromat: Initialization

@author Wouter Beek
@version 2018
*/

:- use_module(library(apply)).
:- use_module(library(settings)).

:- use_module(library(conf_ext)).
:- use_module(library(file_ext)).
:- use_module(library(ll/ll_loop)).
:- use_module(library(ll/ll_metadata)).
:- use_module(library(thread_ext)).

:- dynamic
    user:message_hook/3.

:- initialization
   init_ll.

:- multifile
    user:message_hook/3.

:- set_prolog_stack(global, limit(10*10**9)). %TBD

:- setting(ll:authority, any, _,
           "URI scheme of the seedlist server location.").
:- setting(ll:data_directory, any, _,
           "The directory where clean data is stored and where logs are kept.").
:- setting(ll:password, any, _, "").
:- setting(ll:scheme, oneof([http,https]), https,
           "URI scheme of the seedlist server location.").
:- setting(ll:user, any, _, "").

user:message_hook(E, Kind, _) :-
  memberchk(Kind, [error,warning]),
  thread_self_property(alias(Hash)),
  write_meta_error(Hash, E).





%! init_ll is det.

init_ll :-
  conf_json(Conf),
  % data directory
  create_directory(Conf.'data-directory'),
  set_setting(ll:data_directory, Conf.'data-directory'),
  % seedlist
  maplist(
    set_setting,
    [ll:authority,ll:password,ll:scheme,ll:user],
    [
      Conf.seedlist.authority,
      Conf.seedlist.password,
      Conf.seedlist.scheme,
      Conf.seedlist.user
    ]
  ),
  % workers
  run_loop(ll_download:ll_download, Conf.workers.download),
  run_loop(ll_decompress:ll_decompress, Conf.workers.decompress),
  run_loop(ll_recode:ll_recode, Conf.workers.recode),
  run_loop(ll_parse:ll_parse, Conf.workers.parse),
  % log standard output
  directory_file_path(Conf.'data-directory', 'out.log', File),
  protocol(File).
