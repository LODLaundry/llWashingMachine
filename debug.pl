% Debug tools for the llWashingMachine project.



% Avoid errors when using gtrace/0 in threads.
:- initialization(guitracer).



% Customize the way in which terminal and GUI tracer appear.

:- use_module(library(ansi_term)).

:- set_prolog_flag(
     answer_write_options,
     [max_depth(10),portrayed(true),spacing(next_argument)]
   ).
:- set_prolog_flag(
     debugger_write_options,
     [max_depth(10),portrayed(true),spacing(next_argument)]
   ).



% Show/hide debug messages per category.

:- use_module(library(debug)).

% ClioPatria debug tools.

%%%%:- debug(sparql_graph_store).
%%%%:- debug(sparql_update).

% LOD Washing Machine-specific debug messages that do not fit anywhere else.
%%%%:- debug(lwm_generic).

% Show idle looping on threads.
%%%%:- debug(lwm_idle_loop(clean_large)).
%%%%:- debug(lwm_idle_loop(clean_medium)).
%%%%:- debug(lwm_idle_loop(clean_small)).
:- debug(lwm_idle_loop(unpack)).

% Show progress.
:- debug(lwm_progress(clean_large)).
:- debug(lwm_progress(clean_medium)).
%%%%:- debug(lwm_progress(clean_small)).
%%%%:- debug(lwm_progress(unpack)).



% Debugging specific data documents, based on their MD5.

:- dynamic(debug:debug_md5/2).
:- multifile(debug:debug_md5/2).

debug:debug_md5('3e380c1a60d23f82271346f8c132633b', clean).



show_idle:-
  flag(number_of_idle_loops_clean_small, Small, Small),
  flag(number_of_idle_loops_clean_medium, Medium, Medium),
  flag(number_of_idle_loops_clean_large, Large, Large),
  format(
    user_output,
    'Idle loops:\n  - Small: ~D\n  - Medium: ~D\n  - Large: ~D\n',
    [Small,Medium,Large]
  ).
