:- module(
  ll_generics,
  [
    end_task/3,        % +Hash, +Aliases, +State
    finish/2,          % +Hash, +State
    handle_status/4,   % +Hash, +Status, +Alias, +State
    hash_entry_hash/3, % +Hash1, +Entry, -Hash2
    hash_file/3,       % +Hash, +Local, -File
    start_task/3       % +Alias, -Hash, State
  ]
).

/** <module> LOD Laundromat: Generics

@author Wouter Beek
@version 2017-2018
*/

:- use_module(library(lists)).

:- use_module(library(file_ext)).
:- use_module(library(hash_ext)).
:- use_module(library(ll/ll_metadata)).
:- use_module(library(rocks_ext)).
:- use_module(library(semweb/ldfs)).





%! end_task(+Hash:atom, +Aliase:atom, +State:dict) is det.

end_task(Hash, Alias, State) :-
  rocks_put(Alias, Hash, State).



%! finish(+Hash:atom, +State:dict) is det.

finish(Hash, State) :-
  forall(
    (
      member(Base, [data,error,meta,warning]),
      file_name_extension(Base, nq, Local),
      hash_file(Hash, Local, File),
      exists_file(File)
    ),
    (
      compress_file(File),
      delete_file(File)
    )
  ),
  hash_file(Hash, finished, File),
  touch(File),
  rocks_put(seeds, Hash, State).



%! handle_status(+Hash:atom, +Status, +Alias:atom, +State:dict) is det.

% Successfully parsed means the job is done.  Status may be
% uninstantiated, e.g., when coming from `catch(some_task, Status,
% true)'.
handle_status(Hash, true, Alias, State) :- !,
  (   % The last task has completed successfully.  The state is added
      % to the seedlist.
      Alias == seeds
  ->  finish(Hash, State)
  ;   % A non-last task has completed successfully.
      end_task(Hash, Alias, State)
  ).
% Use the state returned by thread_exit/1 if available.
handle_status(Hash, exited(State), Alias, _) :- !,
  handle_status(Hash, true, Alias, State).
% Unsuccessfully ended the last task menas the job is over.
handle_status(Hash, Status, _, State) :-
  status_error(Status, E),
  write_message(error, Hash, E),
  finish(Hash, State).

status_error(exception(E), E) :- !.
status_error(E, E).



%! hash_entry_hash(+Hash1:atom, +Entry:atom, -Hash2:atom) is det.

hash_entry_hash(Hash1, Entry, Hash2) :-
  md5(Hash1-Entry, Hash2).



%! hash_file(+Hash:atom, +Local:atom, -File:atom) is det.

hash_file(Hash, Local, File) :-
  ldfs_root(Root),
  hash_file(Root, Hash, Local, File).



%! start_task(+Alias:atom, -Hash:atom, -State:dict) is det.

start_task(Alias, Hash, State) :-
  with_mutex(ll_generics, (
    rocks_enum(Alias, Hash, State),
    rocks_delete(Alias, Hash, _)
  )).
