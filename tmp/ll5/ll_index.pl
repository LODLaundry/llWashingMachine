:- module(ll_index, [ll_index/0]).

/** <module> LOD Laundromat: Parse RDF

@author Wouter Beek
@version 2017/09-2017/10
*/

:- use_module(library(semweb/hdt_api)).
:- use_module(library(semweb/rdf_api)).

:- use_module(ll_generics).
:- use_module(ll_seedlist).

:- rdf_register_prefix(base, 'https://lodlaundromat.org/header/').





ll_index :-
  with_mutex(ll_index, (
    seed(Seed),
    Hash{status: generated} :< Seed,
    seed_merge(Hash{status: indexing})
  )),
  debug(ll(index), "┌─> indexing (~a)", [Hash]),
  hash_file(Hash, 'clean.nq.gz', RdfFile),
  hash_file(Hash, 'clean.hdt', HdtFile),
  rdf_global_id(base:Hash, BaseUri),
  hdt_create(RdfFile, HdtFile, [base_uri(BaseUri)]),
  debug(ll(index), "└─< indexed", []),
  with_mutex(ll_index, seed_merge(Hash{status: indexed})).