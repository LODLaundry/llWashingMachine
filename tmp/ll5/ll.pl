:- module(ll, []).

/** <module> LOD Laundromat

@author Wouter Beek
@version 2017/09-2017/11
*/

:- use_module(library(apply)).

:- use_module(ll_analysis).
:- use_module(ll_cloud).
:- use_module(ll_download).
:- use_module(ll_generics).
:- use_module(ll_guess).
:- use_module(ll_parse).
:- use_module(ll_seedlist).
:- use_module(ll_show).
:- use_module(ll_unarchive).

:- initialization
   maplist(call_loop, [ll_download,ll_unarchive,ll_guess,ll_parse,ll_store]).