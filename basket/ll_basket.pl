:- module(
  ll_basket,
  [
    add_to_basket/1, % +Url:url
    cleaned/1, % ?Md5:atom
    pending/1, % ?Md5:atom
    pick_pending/1, % +Md5:atom
    pick_unpacked/1 % +Md5:atom
  ]
).

/** <module> LOD Laundromat: basket

The LOD basket for URLs that are to be processed by the LOD Washing Machine.

~~~{.sh}
$ curl --data "url=http://acm.rkbexplorer.com/id/998550" http://lodlaundry.wbeek.ops.few.vu.nl/lwm/basket
~~~

@author Wouter Beek
@version 2014/05-2014/06, 2014/08
*/

:- use_module(library(semweb/rdf_db)).
:- use_module(library(uri)).

:- use_module(plRdf_term(rdf_literal)).

:- use_module(ll_sparql(ll_sparql_api)).
:- use_module(lwm(store_triple)).



%! add_to_basket(+Source) is det.

add_to_basket(Url1):-
  uri_iri(Url2, Url1),
  with_mutex(ll_basket, (
    rdf_atom_md5(Url2, 1, Md5),
    (
      added(Md5)
    ->
      print_message(informational, already_added(Md5))
    ;
      store_url(Md5, Url2)
    )
  )).


%! added(+Md5:atom) is semidet.

added(Md5):-
  with_mutex(ll_basket, (
    catch(
      ll_sparql_ask([ll],
        [rdf(var(md5),ll:md5,literal(type(xsd:string,Md5))),
         rdf(var(md5),ll:added,var(added))], []),
      _,
      fail
    )
  )).


%! cleaned(+Md5:atom) is semidet.
%! cleaned(-Md5:atom) is nondet.

cleaned(Md5):-
  var(Md5), !,
  with_mutex(ll_basket, (
    ll_sparql_select([ll], [md5],
        [rdf(var(md5res),ll:end_clean,var(end_clean)),
         rdf(var(md5res),ll:md5,var(md5))],
        [[Literal]], [limit(1)]),
    rdf_literal(Literal, Md5, _)
  )).
cleaned(Md5):-
  with_mutex(ll_basket, (
    ll_sparql_ask([ll],
        [rdf(var(md5),ll:md5,literal(type(xsd:string,Md5))),
         rdf(var(md5),ll:end_clean,var(end))], [])
  )).


%! cleaning(+Md5:atom) is semidet.
%! cleaning(-Md5:atom) is nondet.

cleaning(Md5):-
  var(Md5), !,
  with_mutex(ll_basket, (
    ll_sparql_select([ll], [md5],
        [rdf(var(md5res),ll:start_clean,var(start_clean)),
         not([rdf(var(md5res),ll:end_clean,var(end_clean))]),
         rdf(var(md5res),ll:md5,var(md5))],
        [[Literal]], [limit(1)]),
    rdf_literal(Literal, Md5, _)
  )).
cleaning(Md5):-
  with_mutex(ll_basket, (
    ll_sparql_ask([ll],
        [rdf(var(md5),ll:md5,literal(type(xsd:string,Md5))),
         rdf(var(md5),ll:start_clean,var(end)),
         not([rdf(var(md5),ll:end_clean,var(end))])],
        [])
  )).


%! pending(+Md5:atom) is semidet.
%! pending(-Md5:atom) is nondet.

pending(Md5):-
  var(Md5), !,
  with_mutex(ll_basket, (
    ll_sparql_select([ll], [md5],
        [rdf(var(md5res),ll:added,var(added)),
         not([rdf(var(md5res),ll:start_unpack,var(start))]),
         rdf(var(md5res),ll:md5,var(md5))],
        [[Literal]], [limit(1)]),
    rdf_literal(Literal, Md5, _)
  )).
pending(Md5):-
  with_mutex(ll_basket, (
    ll_sparql_ask([ll],
        [rdf(var(md5),ll:md5,literal(type(xsd:string,Md5))),
         rdf(var(md5),ll:added,var(added)),
         not([rdf(var(md5),ll:start_unpack,var(start))])], [])
  )).


% pick_pending(-Md5:atom) is det.

pick_pending(Md5):-
  with_mutex(ll_basket, (
    pending(Md5),
    store_start_unpack(Md5)
  )).


% pick_unpacked(-Md5:atom) is det.

pick_unpacked(Md5):-
  with_mutex(ll_basket, (
    unpacked(Md5),
    store_start_clean(Md5)
  )).


%! unpacked(+Md5:atom) is semidet.
%! unpacked(-Md5:atom) is nondet.

unpacked(Md5):-
  var(Md5), !,
  with_mutex(ll_basket, (
    ll_sparql_select([ll], [md5],
        [rdf(var(md5res),ll:end_unpack,var(start)),
         not([rdf(var(md5res),ll:start_clean,var(clean))]),
         rdf(var(md5res),ll:md5,var(md5))],
        [[Literal]], [limit(1)]),
    rdf_literal(Literal, Md5, _)
  )).
unpacked(Md5):-
  with_mutex(ll_basket, (
    ll_sparql_ask([ll],
        [rdf(var(md5),ll:md5,literal(type(xsd:string,Md5))),
         rdf(var(md5),ll:end_unpack,var(start)),
         not([rdf(var(md5res),ll:start_clean,var(clean))])],
        [])
  )).


%! unpacking(+Md5:atom) is semidet.
%! unpacking(-Md5:atom) is nondet.

unpacking(Md5):-
  var(Md5), !,
  with_mutex(ll_basket, (
    ll_sparql_select([ll], [md5],
        [rdf(var(md5res),ll:start_unpack,var(start)),
         not([rdf(var(md5res),ll:end_unpack,var(clean))]),
         rdf(var(md5res),ll:md5,var(md5))],
        [[Literal]], [limit(1)]),
    rdf_literal(Literal, Md5, _)
  )).
unpacking(Md5):-
  with_mutex(ll_basket, (
    ll_sparql_ask([ll],
        [rdf(var(md5),ll:md5,literal(type(xsd:string,Md5))),
         rdf(var(md5),ll:start_unpack,var(start)),
         not([rdf(var(md5res),ll:end_unpack,var(clean))])],
        [])
  )).



% Messages

:- multifile(prolog:message//1).

prolog:message(already_added(Md5)) -->
  cannot_add(Md5),
  ['already added'].

cannot_add(Md5) -->
  ['MD5 ~w cannot be added to the pool: '-[Md5]].
