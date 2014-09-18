:- module(
  lwm_restart,
  [
    lwm_restart/0
  ]
).

/** <module> LOD Washing Machine: reset

Restart the LOD Washing Machine during debugging.

@author Wouter Beek
@version 2014/08
*/

:- use_module(library(debug)).
:- use_module(library(http/http_client)).

:- use_module(generics(uri_query)).

:- use_module(plSparql(sparql_db)).

:- use_module(lwm(lwm_settings)).



%! lwm_restart is det.

lwm_restart:-
  lwm_version_graph(Graph),

  % Virtuoso implements SPARQL Updates so irregularly,
  % that we cannot even use options for it:
  % (1) No support for direct POST bodies (only URL encoded).
  % (2) GET method for DROP GRAPH.
  % (3) Required SILENT keyword.
  sparql_endpoint_location(virtuoso_update, update, Url1),
  format(atom(Query), 'DROP SILENT GRAPH <~a>', [Graph]),
  uri_query_add_nvpair(Url1, query, Query, Url2),
  http_get(Url2, Reply, []), !,
  debug(lwm_generic, '~a', [Reply]).

